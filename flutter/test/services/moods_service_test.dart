import 'dart:convert';

import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/services/moods_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _mom =
    Member(id: 'p1', familyId: 'f1', role: MemberRole.parent, name: '엄마');
const _harin =
    Member(id: 'k1', familyId: 'f1', role: MemberRole.kid, name: '하린');

/// (method, path) → (status, body). 등록 안 된 요청은 200 []로 응답.
typedef _Route = (int, Object?) Function(http.Request);

void main() {
  late List<http.Request> requests;
  Member? current;

  SupabaseMoodsService service(Map<String, _Route> routes) {
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
    return SupabaseMoodsService(
      client,
      currentMember: () async => current,
      // 로컬 시각 기준 날짜를 쓴다 (UTC로 바꾸면 한국 아침에 전날로 저장된다).
      now: () => DateTime(2026, 10, 23, 7, 30),
    );
  }

  http.Request only(String method, String path) =>
      requests.singleWhere((r) => r.method == method && r.url.path == path);

  setUp(() => current = _mom);

  group('fetchTodayMoods', () {
    test('오늘 날짜 moods를 읽고 RLS가 돌려준 mood_notes만 합친다', () async {
      final s = service({
        'GET /rest/v1/moods': (_) => (
              200,
              [
                {
                  'id': 'm1',
                  'member_id': 'k1',
                  'date': '2026-10-23',
                  'emoji': '😢'
                },
                {
                  'id': 'm2',
                  'member_id': 'k2',
                  'date': '2026-10-23',
                  'emoji': '🙂'
                },
              ]
            ),
        // RLS가 m2(형제) note를 걸렀다고 가정 — m1만 돌아온다.
        'GET /rest/v1/mood_notes': (_) => (
              200,
              [
                {'mood_id': 'm1', 'note': '넘어졌어'},
              ]
            ),
      });

      final result = await s.fetchTodayMoods();

      final moodsReq = only('GET', '/rest/v1/moods');
      expect(moodsReq.url.queryParameters['date'], 'eq.2026-10-23');
      expect(moodsReq.url.queryParameters['select'], 'id,member_id,date,emoji');
      // family_id 재필터링 없음 (ADR-004: RLS에 맡긴다)
      expect(moodsReq.url.queryParameters.containsKey('family_id'), isFalse);

      final notesReq = only('GET', '/rest/v1/mood_notes');
      expect(notesReq.url.queryParameters['mood_id'], 'in.("m1","m2")');

      expect(result.map((m) => (m.memberId, m.emoji, m.note)), [
        ('k1', '😢', '넘어졌어'),
        ('k2', '🙂', null),
      ]);
    });

    test('오늘 기분이 하나도 없으면 mood_notes를 조회하지 않는다', () async {
      final s = service({});
      expect(await s.fetchTodayMoods(), isEmpty);
      expect(requests.map((r) => r.url.path), ['/rest/v1/moods']);
    });

    test('조회 실패는 예외로 올린다', () async {
      final s = service({
        'GET /rest/v1/moods': (_) => (500, {'message': 'boom'}),
      });
      expect(s.fetchTodayMoods(), throwsA(isA<PostgrestException>()));
    });
  });

  group('fetchMyWeeklyMoods', () {
    test('member_id + 최근 7일(오늘 포함) 범위로 조회한다', () async {
      final s = service({
        'GET /rest/v1/moods': (_) => (
              200,
              [
                {
                  'id': 'm1',
                  'member_id': 'k1',
                  'date': '2026-10-20',
                  'emoji': '😆'
                },
              ]
            ),
        'GET /rest/v1/mood_notes': (_) => (
              200,
              [
                {'mood_id': 'm1', 'note': '놀이터'},
              ]
            ),
      });

      final result = await s.fetchMyWeeklyMoods('k1');

      final q = only('GET', '/rest/v1/moods').url.queryParametersAll;
      expect(q['member_id'], ['eq.k1']);
      expect(q['date'], containsAll(['gte.2026-10-17', 'lte.2026-10-23']));

      expect(result.single.id, 'm1');
      expect(result.single.date, '2026-10-20');
      expect(result.single.note, '놀이터');
    });
  });

  group('saveMood', () {
    Map<String, _Route> saveRoutes({List<Map<String, Object?>>? kidRooms}) => {
          'POST /rest/v1/moods': (_) => (201, {'id': 'm9'}),
          'POST /rest/v1/mood_notes': (_) => (201, null),
          'GET /rest/v1/rooms': (_) => (200, kidRooms ?? []),
          'POST /rest/v1/messages': (_) => (201, null),
        };

    test('로그인 안 했으면 StateError', () async {
      current = null;
      final s = service(saveRoutes());
      expect(s.saveMood('🙂'), throwsStateError);
    });

    test('moods를 (member_id,date) 충돌 기준으로 upsert하고 note는 mood_id 기준으로 upsert',
        () async {
      final s = service(saveRoutes());

      final notified = await s.saveMood('🙂', note: '  맛있는 저녁  ');

      final moodReq = only('POST', '/rest/v1/moods');
      expect(moodReq.url.queryParameters['on_conflict'], 'member_id,date');
      expect(
          moodReq.headers['Prefer'], contains('resolution=merge-duplicates'));
      expect(jsonDecode(moodReq.body), {
        'member_id': 'p1',
        'family_id': 'f1',
        'date': '2026-10-23',
        'emoji': '🙂',
      });

      final noteReq = only('POST', '/rest/v1/mood_notes');
      expect(noteReq.url.queryParameters['on_conflict'], 'mood_id');
      expect(jsonDecode(noteReq.body), {'mood_id': 'm9', 'note': '맛있는 저녁'});

      expect(notified, isFalse);
      expect(requests.any((r) => r.url.path == '/rest/v1/messages'), isFalse);
    });

    test('note가 비었거나 공백뿐이면 mood_notes를 쓰지 않는다', () async {
      final s = service(saveRoutes());
      await s.saveMood('😐', note: '   ');
      expect(requests.any((r) => r.url.path == '/rest/v1/mood_notes'), isFalse);
    });

    test('보호자가 슬픔을 골라도 1:1방 알림은 보내지 않는다', () async {
      final s = service(saveRoutes(kidRooms: [
        {'id': 'rk'}
      ]));
      final notified = await s.saveMood('😢');
      expect(notified, isFalse);
      expect(requests.any((r) => r.url.path == '/rest/v1/rooms'), isFalse);
      expect(requests.any((r) => r.url.path == '/rest/v1/messages'), isFalse);
    });

    test('아이가 즐거운 기분이면 알림을 보내지 않는다', () async {
      current = _harin;
      final s = service(saveRoutes(kidRooms: [
        {'id': 'rk'}
      ]));
      expect(await s.saveMood('😆'), isFalse);
      expect(requests.any((r) => r.url.path == '/rest/v1/messages'), isFalse);
    });

    test('아이가 슬픔/화남이면 RLS가 돌려준 본인 1:1방에 알림 메시지를 보낸다', () async {
      current = _harin;
      final s = service(saveRoutes(kidRooms: [
        {'id': 'rk'}
      ]));

      final notified = await s.saveMood('😠', note: '동생이 장난감 뺏음');

      final roomsReq = only('GET', '/rest/v1/rooms');
      expect(roomsReq.url.queryParameters['type'], 'eq.kid');
      // kid_member_id/family_id 재필터링 없음 — RLS가 본인 방만 돌려준다.
      expect(
          roomsReq.url.queryParameters.containsKey('kid_member_id'), isFalse);

      final msgReq = only('POST', '/rest/v1/messages');
      expect(jsonDecode(msgReq.body), {
        'room_id': 'rk',
        'sender_id': 'k1',
        'kind': 'text',
        'body': '오늘 기분: 😠 — 동생이 장난감 뺏음',
      });
      expect(notified, isTrue);
    });

    test('이유가 없으면 이모지만 담아 알린다', () async {
      current = _harin;
      final s = service(saveRoutes(kidRooms: [
        {'id': 'rk'}
      ]));
      await s.saveMood('😢');
      expect(jsonDecode(only('POST', '/rest/v1/messages').body)['body'],
          '오늘 기분: 😢');
    });

    test('아이의 1:1방이 없으면 메시지 없이 끝나고 false', () async {
      current = _harin;
      final s = service(saveRoutes());
      expect(await s.saveMood('😢'), isFalse);
      expect(requests.any((r) => r.url.path == '/rest/v1/messages'), isFalse);
    });

    test('moods 저장 실패면 note/알림을 진행하지 않고 예외', () async {
      current = _harin;
      final s = service({
        ...saveRoutes(kidRooms: [
          {'id': 'rk'}
        ]),
        'POST /rest/v1/moods': (_) => (403, {'message': 'rls'}),
      });
      await expectLater(
          s.saveMood('😢', note: '슬퍼'), throwsA(isA<PostgrestException>()));
      expect(requests.map((r) => r.url.path), ['/rest/v1/moods']);
    });
  });
}
