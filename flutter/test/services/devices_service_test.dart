import 'dart:convert';

import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/services/devices_service.dart';
import 'package:family_toktok/utils/push_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _harin =
    Member(id: 'k1', familyId: 'f1', role: MemberRole.kid, name: '하린');

typedef _Route = (int, Object?) Function(http.Request);

void main() {
  late List<http.Request> requests;
  Member? current;

  SupabaseDevicesService service(Map<String, _Route> routes) {
    requests = [];
    final client = SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final key = '${request.method} ${request.url.path}';
        final (status, body) = routes[key]?.call(request) ?? (200, <Object>[]);
        return http.Response(body == null ? '' : jsonEncode(body), status,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return SupabaseDevicesService(client, currentMember: () async => current);
  }

  Iterable<http.Request> byMethod(String method) => requests
      .where((r) => r.method == method && r.url.path == '/rest/v1/devices');

  setUp(() => current = _harin);

  group('registerDevice', () {
    test('처음 보는 토큰이면 provider: fcm을 명시해 insert한다', () async {
      final s = service({
        'GET /rest/v1/devices': (_) => (200, <Object>[]),
        'POST /rest/v1/devices': (_) => (201, null),
      });

      await s.registerDevice('fcm-token-1', DevicePlatform.android);

      final insert = byMethod('POST').single;
      final body = jsonDecode(insert.body);
      final row = body is List ? body.single : body;
      // 이 계약을 놓치면 default 'expo'가 들어가 backend가 Expo Push API로 잘못 발송한다.
      expect(row['provider'], 'fcm');
      expect(row, {
        'member_id': 'k1',
        'push_token': 'fcm-token-1',
        'platform': 'android',
        'provider': 'fcm',
      });
    });

    test('iOS 기기도 platform: ios + provider: fcm으로 insert한다', () async {
      final s = service({
        'GET /rest/v1/devices': (_) => (200, <Object>[]),
        'POST /rest/v1/devices': (_) => (201, null),
      });

      await s.registerDevice('fcm-token-ios', DevicePlatform.ios);

      final body = jsonDecode(byMethod('POST').single.body);
      final row = body is List ? body.single : body;
      expect(row['platform'], 'ios');
      expect(row['provider'], 'fcm');
    });

    test('insert 전에 member_id + push_token으로 기존 행을 먼저 조회한다', () async {
      final s = service({
        'GET /rest/v1/devices': (_) => (200, <Object>[]),
        'POST /rest/v1/devices': (_) => (201, null),
      });

      await s.registerDevice('fcm-token-1', DevicePlatform.android);

      final select = byMethod('GET').single;
      expect(select.url.queryParameters['member_id'], 'eq.k1');
      expect(select.url.queryParameters['push_token'], 'eq.fcm-token-1');
      // family_id로 재필터링하지 않는다 (RLS 담당).
      expect(select.url.queryParameters.containsKey('family_id'), isFalse);
      expect(requests.indexOf(select),
          lessThan(requests.indexOf(byMethod('POST').single)));
    });

    test('이미 등록된 토큰이면 insert하지 않는다 (중복 방지)', () async {
      final s = service({
        'GET /rest/v1/devices': (_) => (
              200,
              [
                {'id': 'd1'}
              ]
            ),
      });

      await s.registerDevice('fcm-token-1', DevicePlatform.android);

      expect(byMethod('POST'), isEmpty);
    });

    test('로그인한 구성원이 없으면 아무 요청도 보내지 않는다', () async {
      current = null;
      final s = service({});

      await s.registerDevice('fcm-token-1', DevicePlatform.android);

      expect(requests, isEmpty);
    });

    test('insert 실패는 호출자에게 전달한다 (soft-fail은 AuthController 담당)', () async {
      final s = service({
        'GET /rest/v1/devices': (_) => (200, <Object>[]),
        'POST /rest/v1/devices': (_) =>
            (403, {'message': 'new row violates row-level security policy'}),
      });

      await expectLater(
        s.registerDevice('fcm-token-1', DevicePlatform.android),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('unregisterDevice', () {
    test('push_token으로 delete한다 (member_id 체크는 RLS 담당)', () async {
      final s = service({'DELETE /rest/v1/devices': (_) => (204, null)});

      await s.unregisterDevice('fcm-token-1');

      final delete = byMethod('DELETE').single;
      expect(delete.url.queryParameters['push_token'], 'eq.fcm-token-1');
      expect(delete.url.queryParameters.containsKey('member_id'), isFalse);
    });
  });
}
