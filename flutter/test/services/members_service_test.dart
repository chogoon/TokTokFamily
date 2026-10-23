import 'dart:convert';

import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/services/members_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<http.Request> requests;

  SupabaseClient clientReturning(int status, Object body) {
    requests = [];
    return SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        // postgrest는 response.request를 참조하므로 원 요청을 붙여 돌려준다.
        return http.Response(jsonEncode(body), status,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  test('members를 created_at 오름차순으로 조회하고 family_id 재필터 없이 RLS에 맡긴다',
      () async {
    final service = SupabaseMembersService(clientReturning(200, [
      {
        'id': 'p1',
        'family_id': 'f1',
        'role': 'parent',
        'name': '엄마',
        'avatar': null,
        'color': null,
      },
      {
        'id': 'k1',
        'family_id': 'f1',
        'role': 'kid',
        'name': '하린',
        'avatar': '🐰',
        'color': '#FFB547',
      },
    ]));

    final members = await service.fetchFamilyMembers();

    expect(members.map((m) => m.id), ['p1', 'k1']);
    expect(members[1].role, MemberRole.kid);
    expect(members[1].avatar, '🐰');

    final req = requests.single;
    expect(req.method, 'GET');
    expect(req.url.path, '/rest/v1/members');
    expect(req.url.queryParameters['select'],
        'id,family_id,role,name,avatar,color');
    // postgrest-dart는 ascending일 때 nullslast를 덧붙인다.
    expect(req.url.queryParameters['order'], startsWith('created_at.asc'));
    expect(req.url.queryParameters.containsKey('family_id'), isFalse);
  });

  test('조회 실패면 예외를 던진다', () async {
    final service = SupabaseMembersService(clientReturning(
        400, {'message': 'boom', 'code': '42703', 'details': null, 'hint': null}));

    await expectLater(
        service.fetchFamilyMembers(), throwsA(isA<PostgrestException>()));
  });
}
