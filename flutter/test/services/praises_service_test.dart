import 'dart:convert';

import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/models/praise.dart';
import 'package:family_toktok/services/members_service.dart';
import 'package:family_toktok/services/praises_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _mom =
    Member(id: 'p1', familyId: 'f1', role: MemberRole.parent, name: '엄마');
const _harin =
    Member(id: 'k1', familyId: 'f1', role: MemberRole.kid, name: '하린');
const _jun = Member(id: 'k2', familyId: 'f1', role: MemberRole.kid, name: '준');

class _FakeMembers implements MembersService {
  int fetches = 0;
  @override
  Future<List<Member>> fetchFamilyMembers() async {
    fetches++;
    return const [_mom, _harin, _jun];
  }
}

typedef _Route = (int, Object?) Function(http.Request);

Map<String, Object?> _boardRow(String id, String kid,
        {String goal = '보드게임', String status = 'active'}) =>
    {
      'id': id,
      'kid_member_id': kid,
      'family_id': 'f1',
      'goal_text': goal,
      'target_count': 10,
      'status': status,
    };

const _pgError = {
  'message': 'boom',
  'code': 'x',
  'details': null,
  'hint': null
};

void main() {
  late List<http.Request> requests;
  late _FakeMembers members;
  Member? current;

  SupabasePraisesService service(Map<String, _Route> routes) {
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
    return SupabasePraisesService(client,
        members: members, currentMember: () async => current);
  }

  Iterable<http.Request> posts(String table) => requests
      .where((r) => r.method == 'POST' && r.url.path == '/rest/v1/$table');

  setUp(() {
    members = _FakeMembers();
    current = _mom;
  });

  group('fetchActiveBoard', () {
    test('kid_member_id + status=active로 조회해 PraiseBoard로 변환', () async {
      final s = service({
        'GET /rest/v1/praise_boards': (_) => (200, [_boardRow('b1', 'k1')]),
      });
      final board = await s.fetchActiveBoard('k1');
      expect(board?.id, 'b1');
      expect(board?.goalText, '보드게임');
      expect(board?.targetCount, 10);
      expect(board?.status, PraiseBoardStatus.active);

      final q = requests.single.url.queryParameters;
      expect(q['select'],
          'id,kid_member_id,family_id,goal_text,target_count,status');
      expect(q['kid_member_id'], 'eq.k1');
      expect(q['status'], 'eq.active');
      // RLS에 맡기므로 family_id 재필터링 없음
      expect(q.containsKey('family_id'), isFalse);
    });

    test('없으면 null', () async {
      final s = service({});
      expect(await s.fetchActiveBoard('k1'), isNull);
    });

    test('조회 실패면 예외', () async {
      final s = service({
        'GET /rest/v1/praise_boards': (_) => (400, _pgError),
      });
      await expectLater(
          s.fetchActiveBoard('k1'), throwsA(isA<PostgrestException>()));
    });
  });

  group('fetchPraises', () {
    test('board_id로 조회, 준 사람 이름 채움(모르면 "가족") + 최신순', () async {
      final s = service({
        'GET /rest/v1/praises': (_) => (
              200,
              [
                {
                  'id': 'old',
                  'board_id': 'b1',
                  'giver_id': 'p1',
                  'text': '숙제',
                  'created_at': '2026-10-20T09:00:00Z',
                },
                {
                  'id': 'new',
                  'board_id': 'b1',
                  'giver_id': 'ghost',
                  'text': '정리',
                  'created_at': '2026-10-21T09:00:00Z',
                },
              ]
            ),
      });
      final list = await s.fetchPraises('b1');
      expect(list.map((p) => p.id), ['new', 'old']);
      expect(list.map((p) => p.giverName), ['가족', '엄마']);

      final q = requests.single.url.queryParameters;
      expect(q['select'], 'id,board_id,giver_id,text,created_at');
      expect(q['board_id'], 'eq.b1');
    });

    test('기록이 없으면 구성원 조회를 생략', () async {
      final s = service({});
      expect(await s.fetchPraises('b1'), isEmpty);
      expect(members.fetches, 0);
    });
  });

  group('addPraise', () {
    test('칭찬 insert 후 그 아이의 1:1방에 system 메시지로 알린다', () async {
      final s = service({
        'GET /rest/v1/praise_boards': (_) => (
              200,
              [
                {'kid_member_id': 'k1'}
              ]
            ),
        'GET /rest/v1/rooms': (_) => (
              200,
              [
                {'id': 'rk1'}
              ]
            ),
        'POST /rest/v1/praises': (_) => (201, null),
        'POST /rest/v1/messages': (_) => (201, null),
      });
      await s.addPraise('b1', '스스로 숙제했어요');

      expect(jsonDecode(posts('praises').single.body), {
        'board_id': 'b1',
        'giver_id': 'p1',
        'text': '스스로 숙제했어요',
      });
      final roomReq =
          requests.firstWhere((r) => r.url.path == '/rest/v1/rooms');
      expect(roomReq.url.queryParameters['type'], 'eq.kid');
      expect(roomReq.url.queryParameters['kid_member_id'], 'eq.k1');
      expect(jsonDecode(posts('messages').single.body), {
        'room_id': 'rk1',
        'sender_id': 'p1',
        'kind': 'system',
        'body': '⭐ 칭찬 스티커! "스스로 숙제했어요"',
      });
    });

    test('1:1방이 없으면 알림 없이 조용히 끝난다', () async {
      final s = service({
        'GET /rest/v1/praise_boards': (_) => (
              200,
              [
                {'kid_member_id': 'k1'}
              ]
            ),
        'POST /rest/v1/praises': (_) => (201, null),
      });
      await s.addPraise('b1', '착해요');
      expect(posts('praises'), hasLength(1));
      expect(posts('messages'), isEmpty);
    });

    test('칭찬판이 없으면 StateError, insert 없음', () async {
      final s = service({});
      await expectLater(s.addPraise('b1', 'x'), throwsA(isA<StateError>()));
      expect(posts('praises'), isEmpty);
    });

    test('로그인 구성원이 없으면 StateError, 요청 없음', () async {
      current = null;
      final s = service({});
      await expectLater(s.addPraise('b1', 'x'), throwsA(isA<StateError>()));
      expect(requests, isEmpty);
    });

    test('insert 실패면 예외, 알림 없음', () async {
      final s = service({
        'GET /rest/v1/praise_boards': (_) => (
              200,
              [
                {'kid_member_id': 'k1'}
              ]
            ),
        'POST /rest/v1/praises': (_) => (403, _pgError),
      });
      await expectLater(
          s.addPraise('b1', 'x'), throwsA(isA<PostgrestException>()));
      expect(posts('messages'), isEmpty);
    });
  });

  group('addPraiseToAllKids', () {
    test('각 아이의 active 판에 insert하고 가족방에 한 건만 알린다', () async {
      final s = service({
        'GET /rest/v1/praise_boards': (r) {
          final kid = r.url.queryParameters['kid_member_id'];
          if (kid == 'eq.k1') return (200, [_boardRow('b1', 'k1')]);
          if (kid == 'eq.k2') return (200, [_boardRow('b2', 'k2')]);
          return (200, <Object>[]);
        },
        'GET /rest/v1/rooms': (_) => (
              200,
              [
                {'id': 'rf'}
              ]
            ),
        'POST /rest/v1/praises': (_) => (201, null),
        'POST /rest/v1/messages': (_) => (201, null),
      });
      await s.addPraiseToAllKids(['k1', 'k2'], '같이 청소했어요');

      expect(posts('praises').map((r) => jsonDecode(r.body)['board_id']),
          ['b1', 'b2']);
      final roomReq =
          requests.firstWhere((r) => r.url.path == '/rest/v1/rooms');
      expect(roomReq.url.queryParameters['type'], 'eq.family');
      final msg = posts('messages').single;
      expect(jsonDecode(msg.body), {
        'room_id': 'rf',
        'sender_id': 'p1',
        'kind': 'system',
        'body': '⭐ 하린, 준 모두 칭찬 스티커! "같이 청소했어요"',
      });
    });

    test('판이 없는 아이는 건너뛴다', () async {
      final s = service({
        'GET /rest/v1/praise_boards': (r) =>
            r.url.queryParameters['kid_member_id'] == 'eq.k1'
                ? (200, [_boardRow('b1', 'k1')])
                : (200, <Object>[]),
        'POST /rest/v1/praises': (_) => (201, null),
      });
      await s.addPraiseToAllKids(['k1', 'k2'], '같이');
      expect(posts('praises'), hasLength(1));
    });

    test('로그인 구성원이 없으면 StateError', () async {
      current = null;
      final s = service({});
      await expectLater(
          s.addPraiseToAllKids(['k1'], 'x'), throwsA(isA<StateError>()));
      expect(requests, isEmpty);
    });
  });

  group('claimReward', () {
    const board = PraiseBoard(
      id: 'b1',
      kidMemberId: 'k1',
      familyId: 'f1',
      goalText: '보드게임',
      targetCount: 10,
      status: PraiseBoardStatus.active,
    );

    test('1:1방 알림 → 기존 판 done → 같은 목표로 새 판 insert', () async {
      final s = service({
        'GET /rest/v1/rooms': (_) => (
              200,
              [
                {'id': 'rk1'}
              ]
            ),
        'POST /rest/v1/messages': (_) => (201, null),
        'PATCH /rest/v1/praise_boards': (_) => (204, null),
        'POST /rest/v1/praise_boards': (_) => (201, null),
      });
      await s.claimReward(board);

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /rest/v1/rooms',
        'POST /rest/v1/messages',
        'PATCH /rest/v1/praise_boards',
        'POST /rest/v1/praise_boards',
      ]);
      expect(jsonDecode(posts('messages').single.body)['body'],
          '🎁 약속한 "보드게임" 지킬게! 새 칭찬판 시작이야');
      final patch = requests.firstWhere((r) => r.method == 'PATCH');
      expect(patch.url.queryParameters['id'], 'eq.b1');
      expect(jsonDecode(patch.body), {'status': 'done'});
      expect(jsonDecode(posts('praise_boards').single.body), {
        'kid_member_id': 'k1',
        'family_id': 'f1',
        'goal_text': '보드게임',
        'target_count': 10,
      });
    });

    test('done 처리 실패면 예외, 새 판 insert 없음', () async {
      final s = service({
        'PATCH /rest/v1/praise_boards': (_) => (403, _pgError),
      });
      await expectLater(
          s.claimReward(board), throwsA(isA<PostgrestException>()));
      expect(posts('praise_boards'), isEmpty);
    });

    test('로그인 구성원이 없으면 StateError', () async {
      current = null;
      final s = service({});
      await expectLater(s.claimReward(board), throwsA(isA<StateError>()));
      expect(requests, isEmpty);
    });
  });

  test('saveGoal: id로 goal_text만 update', () async {
    final s = service({'PATCH /rest/v1/praise_boards': (_) => (204, null)});
    await s.saveGoal('b1', '레고 사기');
    final req = requests.single;
    expect(req.method, 'PATCH');
    expect(req.url.queryParameters['id'], 'eq.b1');
    expect(jsonDecode(req.body), {'goal_text': '레고 사기'});
  });
}
