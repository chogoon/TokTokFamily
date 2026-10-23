import 'dart:convert';

import 'package:family_toktok/models/chat_message.dart';
import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/models/room.dart';
import 'package:family_toktok/services/members_service.dart';
import 'package:family_toktok/services/realtime_gateway.dart';
import 'package:family_toktok/services/rooms_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _mom =
    Member(id: 'p1', familyId: 'f1', role: MemberRole.parent, name: '엄마');
const _harin =
    Member(id: 'k1', familyId: 'f1', role: MemberRole.kid, name: '하린');

class _FakeMembers implements MembersService {
  int fetches = 0;
  @override
  Future<List<Member>> fetchFamilyMembers() async {
    fetches++;
    return const [_mom, _harin];
  }
}

class _Listener {
  _Listener(
      this.channelName, this.table, this.event, this.filter, this.onChange);
  final String channelName;
  final String table;
  final PostgresChangeEvent event;
  final PostgresChangeFilter? filter;
  final RealtimeChangeHandler onChange;
  bool removed = false;
}

class FakeRealtimeGateway implements RealtimeGateway {
  final listeners = <_Listener>[];

  @override
  Unsubscribe listen({
    required String channelName,
    required String table,
    required PostgresChangeEvent event,
    PostgresChangeFilter? filter,
    required RealtimeChangeHandler onChange,
  }) {
    final l = _Listener(channelName, table, event, filter, onChange);
    listeners.add(l);
    return () => l.removed = true;
  }
}

/// (method, path) → (status, body). 등록 안 된 요청은 200 []로 응답.
typedef _Route = (int, Object?) Function(http.Request);

void main() {
  late List<http.Request> requests;
  late _FakeMembers members;
  late FakeRealtimeGateway realtime;
  Member? current;

  SupabaseRoomsService service(Map<String, _Route> routes) {
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
    return SupabaseRoomsService(
      client,
      members: members,
      currentMember: () async => current,
      realtime: realtime,
      now: () => DateTime.utc(2026, 10, 23, 1, 2, 3),
    );
  }

  setUp(() {
    members = _FakeMembers();
    realtime = FakeRealtimeGateway();
    current = _mom;
  });

  group('fetchRooms', () {
    test('rooms/messages/reads를 RLS 범위 그대로 조회해 요약을 만든다', () async {
      final s = service({
        'GET /rest/v1/rooms': (_) => (
              200,
              [
                {
                  'id': 'rf',
                  'family_id': 'f1',
                  'type': 'family',
                  'kid_member_id': null
                },
                {
                  'id': 'rk',
                  'family_id': 'f1',
                  'type': 'kid',
                  'kid_member_id': 'k1'
                },
              ]
            ),
        'GET /rest/v1/messages': (_) => (
              200,
              [
                {
                  'room_id': 'rf',
                  'body': '최신',
                  'created_at': '2026-10-22T10:00:00Z'
                },
                {
                  'room_id': 'rf',
                  'body': '이전',
                  'created_at': '2026-10-22T09:00:00Z'
                },
              ]
            ),
        'GET /rest/v1/reads': (_) => (
              200,
              [
                {'room_id': 'rf', 'last_read_at': '2026-10-22T09:30:00Z'},
              ]
            ),
      });

      final rooms = await s.fetchRooms();

      expect(rooms.map((r) => r.name), ['가족방', '하린와의 대화']);
      expect(rooms[0].lastMessage?.body, '최신');
      expect(rooms[0].hasUnread, isTrue);
      expect(rooms[1].lastMessage, isNull);
      expect(rooms[1].hasUnread, isFalse);

      final roomsReq =
          requests.firstWhere((r) => r.url.path == '/rest/v1/rooms');
      expect(roomsReq.url.queryParameters['select'],
          'id,family_id,type,kid_member_id');
      expect(
          roomsReq.url.queryParameters['order'], startsWith('created_at.asc'));
      // CRITICAL: family_id / kid_member_id로 재필터링하지 않는다 (RLS에 맡김).
      expect(roomsReq.url.queryParameters.containsKey('family_id'), isFalse);
      expect(
          roomsReq.url.queryParameters.containsKey('kid_member_id'), isFalse);

      final msgReq =
          requests.firstWhere((r) => r.url.path == '/rest/v1/messages');
      expect(msgReq.url.queryParameters['room_id'], 'in.("rf","rk")');
      expect(
          msgReq.url.queryParameters['order'], startsWith('created_at.desc'));

      final readsReq =
          requests.firstWhere((r) => r.url.path == '/rest/v1/reads');
      expect(readsReq.url.queryParameters['member_id'], 'eq.p1');
    });

    test('로그인한 구성원이 없으면 조회 없이 빈 목록', () async {
      current = null;
      final s = service({});
      expect(await s.fetchRooms(), isEmpty);
      expect(requests, isEmpty);
    });

    test('방이 없으면 messages/reads를 조회하지 않는다', () async {
      final s = service({});
      expect(await s.fetchRooms(), isEmpty);
      expect(requests.map((r) => r.url.path), ['/rest/v1/rooms']);
    });

    test('rooms 조회 실패면 예외', () async {
      final s = service({
        'GET /rest/v1/rooms': (_) => (
              400,
              {'message': 'boom', 'code': 'x', 'details': null, 'hint': null}
            ),
      });
      await expectLater(s.fetchRooms(), throwsA(isA<PostgrestException>()));
    });
  });

  test('fetchRoomById: id로 단건 조회, 없으면 null', () async {
    final s = service({
      'GET /rest/v1/rooms': (r) => r.url.queryParameters['id'] == 'eq.rf'
          ? (
              200,
              {
                'id': 'rf',
                'family_id': 'f1',
                'type': 'family',
                'kid_member_id': null
              }
            )
          : (
              406,
              {
                'message': 'no rows',
                'code': 'PGRST116',
                'details': null,
                'hint': null
              }
            ),
    });
    final room = await s.fetchRoomById('rf');
    expect(room?.type, RoomType.family);
  });

  test('fetchMessages: 시간 오름차순 + 보낸 사람 이름 채움(모르면 "가족")', () async {
    final s = service({
      'GET /rest/v1/messages': (_) => (
            200,
            [
              {
                'id': 'm1',
                'room_id': 'rf',
                'sender_id': 'k1',
                'kind': 'text',
                'body': '안녕',
                'is_urgent': false,
                'created_at': '2026-10-22T10:00:00Z',
              },
              {
                'id': 'm2',
                'room_id': 'rf',
                'sender_id': 'ghost',
                'kind': 'sticker',
                'body': '🎉',
                'is_urgent': false,
                'created_at': '2026-10-22T10:01:00Z',
              },
            ]
          ),
    });
    final list = await s.fetchMessages('rf');
    expect(list.map((m) => m.senderName), ['하린', '가족']);
    expect(list[1].kind, MessageKind.sticker);

    final req = requests.single;
    expect(req.url.queryParameters['select'],
        'id,room_id,sender_id,kind,body,is_urgent,created_at');
    expect(req.url.queryParameters['room_id'], 'eq.rf');
    expect(req.url.queryParameters['order'], startsWith('created_at.asc'));
  });

  test('fetchMessages: 메시지가 없으면 구성원 조회를 생략', () async {
    final s = service({});
    expect(await s.fetchMessages('rf'), isEmpty);
    expect(members.fetches, 0);
  });

  group('sendMessage / sendSticker', () {
    test('현재 member 명의로 text 메시지를 insert (기본 is_urgent=false)', () async {
      final s = service({'POST /rest/v1/messages': (_) => (201, null)});
      await s.sendMessage('rf', '안녕');
      expect(jsonDecode(requests.single.body), {
        'room_id': 'rf',
        'sender_id': 'p1',
        'kind': 'text',
        'body': '안녕',
        'is_urgent': false,
      });
    });

    test('isUrgent: true면 긴급으로 insert', () async {
      final s = service({'POST /rest/v1/messages': (_) => (201, null)});
      await s.sendMessage('rk', '🚨 데리러 와주세요', isUrgent: true);
      expect(jsonDecode(requests.single.body)['is_urgent'], true);
    });

    test('sendSticker: kind=sticker, body=이모지', () async {
      final s = service({'POST /rest/v1/messages': (_) => (201, null)});
      await s.sendSticker('rf', '🎉');
      expect(jsonDecode(requests.single.body), {
        'room_id': 'rf',
        'sender_id': 'p1',
        'kind': 'sticker',
        'body': '🎉',
      });
    });

    test('로그인 구성원이 없으면 예외, 요청 없음', () async {
      current = null;
      final s = service({});
      await expectLater(s.sendMessage('rf', 'x'), throwsA(isA<StateError>()));
      expect(requests, isEmpty);
    });
  });

  test('fetchMyKidRoomId: type=kid만 필터하고 RLS 결과 첫 행을 쓴다', () async {
    current = _harin;
    final s = service({
      'GET /rest/v1/rooms': (_) => (
            200,
            [
              {'id': 'rk'},
            ]
          ),
    });
    expect(await s.fetchMyKidRoomId(), 'rk');
    final q = requests.single.url.queryParameters;
    expect(q['select'], 'id');
    expect(q['type'], 'eq.kid');
    expect(q.containsKey('kid_member_id'), isFalse);
    expect(q.containsKey('family_id'), isFalse);
  });

  test('fetchMyKidRoomId: 없으면 null', () async {
    final s = service({});
    expect(await s.fetchMyKidRoomId(), isNull);
  });

  group('reactions', () {
    test('fetchReactions: message_id in 조회 후 이모지별로 묶는다', () async {
      final s = service({
        'GET /rest/v1/reactions': (_) => (
              200,
              [
                {'message_id': 'm1', 'member_id': 'p1', 'emoji': '❤️'},
                {'message_id': 'm1', 'member_id': 'k1', 'emoji': '❤️'},
                {'message_id': 'm2', 'member_id': 'k1', 'emoji': '😂'},
              ]
            ),
      });
      final result = await s.fetchReactions(['m1', 'm2']);
      expect(result['m1'], const [
        ReactionSummary(emoji: '❤️', memberIds: ['p1', 'k1'])
      ]);
      expect(result['m2']!.single.emoji, '😂');
      final q = requests.single.url.queryParameters;
      expect(q['select'], 'message_id,member_id,emoji');
      expect(q['message_id'], 'in.("m1","m2")');
    });

    test('fetchReactions: 빈 목록이면 요청 없이 빈 맵', () async {
      final s = service({});
      expect(await s.fetchReactions(const []), isEmpty);
      expect(requests, isEmpty);
    });

    test('toggleReaction: 기존 반응 delete 후 새 반응 insert', () async {
      final s = service({
        'DELETE /rest/v1/reactions': (_) => (204, null),
        'POST /rest/v1/reactions': (_) => (201, null),
      });
      await s.toggleReaction('m1', '❤️', '👍');

      expect(requests.map((r) => r.method), ['DELETE', 'POST']);
      final del = requests[0].url.queryParameters;
      expect(del['message_id'], 'eq.m1');
      expect(del['member_id'], 'eq.p1');
      expect(del['emoji'], 'eq.❤️');
      expect(jsonDecode(requests[1].body),
          {'message_id': 'm1', 'member_id': 'p1', 'emoji': '👍'});
    });

    test('toggleReaction: 현재 반응 없음 → insert만, 다음 반응 없음 → delete만', () async {
      final s = service({
        'DELETE /rest/v1/reactions': (_) => (204, null),
        'POST /rest/v1/reactions': (_) => (201, null),
      });
      await s.toggleReaction('m1', null, '❤️');
      expect(requests.map((r) => r.method), ['POST']);

      requests.clear();
      await s.toggleReaction('m1', '😂', null);
      expect(requests.map((r) => r.method), ['DELETE']);
    });
  });

  test('markRoomRead: reads를 (room_id,member_id) 충돌 기준으로 upsert', () async {
    final s = service({'POST /rest/v1/reads': (_) => (201, null)});
    await s.markRoomRead('rf');
    final req = requests.single;
    expect(req.url.queryParameters['on_conflict'], 'room_id,member_id');
    expect(req.headers['Prefer'], contains('resolution=merge-duplicates'));
    expect(jsonDecode(req.body), {
      'room_id': 'rf',
      'member_id': 'p1',
      'last_read_at': '2026-10-23T01:02:03.000Z',
    });
  });

  test('markRoomRead: 로그인 구성원이 없으면 아무것도 하지 않는다', () async {
    current = null;
    final s = service({});
    await s.markRoomRead('rf');
    expect(requests, isEmpty);
  });

  group('subscribeToMessages', () {
    test('room_id=eq 필터로 INSERT를 구독하고, 이름을 채워 전달, 해제 콜백 반환', () async {
      final s = service({});
      final received = <ChatMessage>[];
      final unsubscribe = s.subscribeToMessages('rf', received.add);
      await Future<void>.delayed(Duration.zero); // 구성원 이름 로딩

      final l = realtime.listeners.single;
      expect(l.table, 'messages');
      expect(l.event, PostgresChangeEvent.insert);
      expect(l.filter.toString(), 'room_id=eq.rf');
      expect(l.channelName, startsWith('messages-room-rf'));

      l.onChange({
        'id': 'm9',
        'room_id': 'rf',
        'sender_id': 'k1',
        'kind': 'text',
        'body': '왔어요',
        'is_urgent': true,
        'created_at': '2026-10-22T10:00:00Z',
      }, const {});
      expect(received.single.senderName, '하린');
      expect(received.single.isUrgent, isTrue);

      unsubscribe();
      expect(l.removed, isTrue);
      // 해제 후 들어온 이벤트는 전달하지 않는다.
      l.onChange({
        'id': 'm10',
        'room_id': 'rf',
        'sender_id': 'k1',
        'kind': 'text',
        'body': 'x',
        'is_urgent': false,
        'created_at': '2026-10-22T10:00:00Z',
      }, const {});
      expect(received, hasLength(1));
    });

    test('같은 방을 두 번 구독해도 채널 이름이 겹치지 않는다', () {
      final s = service({});
      s.subscribeToMessages('rf', (_) {});
      s.subscribeToMessages('rf', (_) {});
      final names = realtime.listeners.map((l) => l.channelName).toSet();
      expect(names, hasLength(2));
    });
  });

  group('subscribeToReactions', () {
    test('목록의 메시지에 대한 INSERT/DELETE만 onChange를 부른다', () {
      final s = service({});
      var changes = 0;
      final unsubscribe = s.subscribeToReactions(['m1', 'm2'], () => changes++);

      final l = realtime.listeners.single;
      expect(l.table, 'reactions');
      expect(l.event, PostgresChangeEvent.all);

      l.onChange(
          {'message_id': 'm1', 'member_id': 'p1', 'emoji': '❤️'}, const {});
      l.onChange(
          const {}, {'message_id': 'm2', 'member_id': 'p1', 'emoji': '❤️'});
      l.onChange(
          {'message_id': 'other', 'member_id': 'p1', 'emoji': '❤️'}, const {});
      expect(changes, 2);

      unsubscribe();
      expect(l.removed, isTrue);
    });

    test('메시지가 없으면 구독하지 않는다', () {
      final s = service({});
      s.subscribeToReactions(const [], () {})();
      expect(realtime.listeners, isEmpty);
    });
  });
}
