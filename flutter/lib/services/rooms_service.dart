import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/member.dart';
import '../models/room.dart';
import '../utils/rooms.dart';
import 'members_service.dart';
import 'realtime_gateway.dart';

export 'realtime_gateway.dart' show Unsubscribe;

/// 로그인한 구성원 (없으면 null). main.dart에서 AuthController.member로 연결한다.
typedef CurrentMemberProvider = Future<Member?> Function();

/// 대화(방/메시지/반응/읽음) 데이터 경계. 화면 테스트에서 fake로 대체한다.
/// RN `frontend/services/rooms.ts`에 대응.
abstract class RoomsService {
  Future<List<RoomSummary>> fetchRooms();
  Future<Room?> fetchRoomById(String roomId);
  Future<List<ChatMessage>> fetchMessages(String roomId);
  Future<void> sendMessage(String roomId, String body, {bool isUrgent = false});
  Future<void> sendSticker(String roomId, String emoji);

  /// 로그인한 **아이 본인**의 1:1방 id (없으면 null).
  ///
  /// rooms를 `type='kid'`로만 필터해 select하고, RLS(rooms_select)가 "아이는 본인
  /// kid_member_id가 일치하는 방만, 보호자는 전체"를 돌려주므로 그 결과의 첫 행을 그대로 쓴다.
  /// family_id나 kid_member_id로 클라이언트가 다시 필터링하지 않는다(그 흉내는 형제 방 유출로
  /// 이어질 수 있다). 보호자가 호출하면 여러 아이의 방이 돌아올 수 있으므로 **kid 역할 member만**
  /// 호출해야 한다 — 호출부에서 역할을 먼저 확인할 것.
  Future<String?> fetchMyKidRoomId();

  Future<Map<String, List<ReactionSummary>>> fetchReactions(
      List<String> messageIds);

  /// 내 기존 반응([currentEmoji])을 지우고(있으면) [nextEmoji]를 넣는다(있으면).
  /// 다음 이모지 계산은 `utils/rooms.dart`의 [nextReactionEmoji]가 한다.
  Future<void> toggleReaction(
      String messageId, String? currentEmoji, String? nextEmoji);

  Future<void> markRoomRead(String roomId);

  /// 해당 방의 새 메시지를 Realtime으로 구독한다. 반환값을 호출하면 구독을 해제한다.
  Unsubscribe subscribeToMessages(
      String roomId, void Function(ChatMessage message) onInsert);

  /// 주어진 메시지들의 반응 추가/삭제를 Realtime으로 구독한다. 반환값을 호출하면 해제한다.
  Unsubscribe subscribeToReactions(
      List<String> messageIds, void Function() onChange);
}

/// Supabase 직접 호출 (ADR-004 "일상 데이터" 경로). 모든 조회는 RLS가 범위를 제한하므로
/// family_id/kid_member_id로 클라이언트 재필터링을 하지 않는다.
class SupabaseRoomsService implements RoomsService {
  SupabaseRoomsService(
    this._client, {
    required MembersService members,
    required CurrentMemberProvider currentMember,
    RealtimeGateway? realtime,
    DateTime Function()? now,
  })  : _members = members,
        _currentMember = currentMember,
        _realtime = realtime ?? SupabaseRealtimeGateway(_client),
        _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final MembersService _members;
  final CurrentMemberProvider _currentMember;
  final RealtimeGateway _realtime;
  final DateTime Function() _now;

  /// 같은 방을 다시 열 때(이전 채널 해제가 끝나기 전) 채널 topic이 겹치지 않도록 붙이는 일련번호.
  int _channelSeq = 0;

  static const _roomColumns = 'id, family_id, type, kid_member_id';
  static const _messageColumns =
      'id, room_id, sender_id, kind, body, is_urgent, created_at';

  Future<Member> _requireMember() async {
    final me = await _currentMember();
    if (me == null) throw StateError('로그인이 필요해요');
    return me;
  }

  @override
  Future<List<RoomSummary>> fetchRooms() async {
    final me = await _currentMember();
    if (me == null) return const [];

    final roomRows = await _client
        .from('rooms')
        .select(_roomColumns)
        .order('created_at', ascending: true);
    final rooms = roomRows.map(Room.fromRow).toList();
    if (rooms.isEmpty) return const [];

    final members = await _members.fetchFamilyMembers();

    final messageRows = await _client
        .from('messages')
        .select('room_id, body, created_at')
        .inFilter('room_id', rooms.map((r) => r.id).toList())
        .order('created_at', ascending: false);
    final lastMessages = pickLastMessagePerRoom([
      for (final row in messageRows)
        RawMessageRow(
          roomId: row['room_id'] as String,
          body: row['body'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ]);

    final readRows = await _client
        .from('reads')
        .select('room_id, last_read_at')
        .eq('member_id', me.id);
    final lastReadAt = {
      for (final row in readRows)
        row['room_id'] as String: DateTime.parse(row['last_read_at'] as String),
    };

    return buildRoomSummaries(rooms, members, lastMessages, lastReadAt);
  }

  @override
  Future<Room?> fetchRoomById(String roomId) async {
    final row = await _client
        .from('rooms')
        .select(_roomColumns)
        .eq('id', roomId)
        .maybeSingle();
    return row == null ? null : Room.fromRow(row);
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String roomId) async {
    final rows = await _client
        .from('messages')
        .select(_messageColumns)
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
    if (rows.isEmpty) return const [];

    final names = await _memberNames();
    return [
      for (final row in rows)
        ChatMessage.fromRow(row, senderName: _nameOf(names, row)),
    ];
  }

  Future<Map<String, String>> _memberNames() async {
    final members = await _members.fetchFamilyMembers();
    return {for (final m in members) m.id: m.name};
  }

  static String _nameOf(Map<String, String> names, Map<String, dynamic> row) =>
      names[row['sender_id']] ?? '가족';

  @override
  Future<void> sendMessage(String roomId, String body,
      {bool isUrgent = false}) async {
    final me = await _requireMember();
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': me.id,
      'kind': 'text',
      'body': body,
      'is_urgent': isUrgent,
    });
  }

  @override
  Future<void> sendSticker(String roomId, String emoji) async {
    final me = await _requireMember();
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': me.id,
      'kind': 'sticker',
      'body': emoji,
    });
  }

  @override
  Future<String?> fetchMyKidRoomId() async {
    final rows = await _client.from('rooms').select('id').eq('type', 'kid');
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  @override
  Future<Map<String, List<ReactionSummary>>> fetchReactions(
      List<String> messageIds) async {
    if (messageIds.isEmpty) return const {};
    final rows = await _client
        .from('reactions')
        .select('message_id, member_id, emoji')
        .inFilter('message_id', messageIds);
    return groupReactions([
      for (final row in rows)
        RawReactionRow(
          messageId: row['message_id'] as String,
          memberId: row['member_id'] as String,
          emoji: row['emoji'] as String,
        ),
    ]);
  }

  @override
  Future<void> toggleReaction(
      String messageId, String? currentEmoji, String? nextEmoji) async {
    final me = await _requireMember();
    if (currentEmoji != null) {
      await _client
          .from('reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('member_id', me.id)
          .eq('emoji', currentEmoji);
    }
    if (nextEmoji != null) {
      await _client.from('reactions').insert({
        'message_id': messageId,
        'member_id': me.id,
        'emoji': nextEmoji,
      });
    }
  }

  @override
  Future<void> markRoomRead(String roomId) async {
    final me = await _currentMember();
    if (me == null) return;
    await _client.from('reads').upsert(
      {
        'room_id': roomId,
        'member_id': me.id,
        'last_read_at': _now().toUtc().toIso8601String(),
      },
      onConflict: 'room_id,member_id',
    );
  }

  @override
  Unsubscribe subscribeToMessages(
      String roomId, void Function(ChatMessage message) onInsert) {
    var cancelled = false;
    var names = const <String, String>{};
    // 이름 조회 실패해도 메시지 수신 자체는 막지 않는다 (기본 이름 "가족"으로 표시).
    _memberNames().then((value) {
      if (!cancelled) names = value;
    }).catchError((Object _) {});

    final unsubscribe = _realtime.listen(
      channelName: 'messages-room-$roomId-${_channelSeq++}',
      table: 'messages',
      event: PostgresChangeEvent.insert,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      onChange: (newRecord, _) {
        if (cancelled) return;
        onInsert(ChatMessage.fromRow(newRecord,
            senderName: _nameOf(names, newRecord)));
      },
    );

    return () {
      cancelled = true;
      unsubscribe();
    };
  }

  @override
  Unsubscribe subscribeToReactions(
      List<String> messageIds, void Function() onChange) {
    if (messageIds.isEmpty) return () {};
    final ids = messageIds.toSet();
    var cancelled = false;

    // reactions에는 room_id가 없어 서버 필터를 걸 수 없다(RN과 동일). RLS 범위의 이벤트를 받아
    // 이 화면 메시지에 대한 것만 걸러낸다. DELETE는 oldRecord(PK 컬럼)에 message_id가 있다.
    final unsubscribe = _realtime.listen(
      channelName: 'reactions-${messageIds.first}-${_channelSeq++}',
      table: 'reactions',
      event: PostgresChangeEvent.all,
      onChange: (newRecord, oldRecord) {
        if (cancelled) return;
        final messageId = newRecord['message_id'] ?? oldRecord['message_id'];
        if (ids.contains(messageId)) onChange();
      },
    );

    return () {
      cancelled = true;
      unsubscribe();
    };
  }
}
