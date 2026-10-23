// services/rooms_service.dart가 쓰는 순수 로직(네트워크 없음). RN `frontend/lib/rooms.ts` 포팅.
import '../models/chat_message.dart';
import '../models/member.dart';
import '../models/room.dart';

/// 방 이름을 계산한다. 가족방은 고정, 1:1방은 아이 이름 기반.
String buildRoomName(Room room, List<Member> members) {
  if (room.type == RoomType.family) return '가족방';
  for (final m in members) {
    if (m.id == room.kidMemberId) return '${m.name}와의 대화';
  }
  return '1:1 대화';
}

/// 마지막 메시지 시각이 마지막 읽음 시각보다 최신이면 안읽음으로 판정한다.
bool isRoomUnread(DateTime? lastMessageCreatedAt, DateTime? lastReadAt) {
  if (lastMessageCreatedAt == null) return false;
  if (lastReadAt == null) return true;
  return lastMessageCreatedAt.isAfter(lastReadAt);
}

class RawMessageRow {
  const RawMessageRow({
    required this.roomId,
    required this.body,
    required this.createdAt,
  });

  final String roomId;
  final String? body;
  final DateTime createdAt;
}

/// created_at 내림차순으로 정렬된 메시지 목록에서 방별 가장 최근 메시지를 뽑는다.
/// 입력 순서를 신뢰하므로(먼저 나오는 행이 최신) 호출 측이 정렬된 데이터를 넘겨야 한다.
Map<String, LastMessagePreview> pickLastMessagePerRoom(
    List<RawMessageRow> rows) {
  final result = <String, LastMessagePreview>{};
  for (final row in rows) {
    result.putIfAbsent(
      row.roomId,
      () => LastMessagePreview(body: row.body, createdAt: row.createdAt),
    );
  }
  return result;
}

/// 메시지에 달 수 있는 반응 이모지 목록 (family-sns.html 프로토타입의 REACTS).
const reactionEmojis = <String>['❤️', '👍', '😂'];

/// 메시지 반응 순환 로직. 내 반응은 최대 1개다.
/// 현재 반응이 없으면 첫 이모지로, 있으면 다음 이모지로, 마지막에서 한 번 더 누르면 null(반응 없음).
/// 목록에 없는 이모지가 들어오면 처음부터 순환한다.
String? nextReactionEmoji(List<String> emojis, String? currentEmoji) {
  final currentIndex = currentEmoji == null ? -1 : emojis.indexOf(currentEmoji);
  final nextIndex = currentIndex + 1;
  return nextIndex < emojis.length ? emojis[nextIndex] : null;
}

/// rooms/members/마지막 메시지/읽음 상태를 합쳐 화면에 쓸 RoomSummary 목록을 만든다.
List<RoomSummary> buildRoomSummaries(
  List<Room> rooms,
  List<Member> members,
  Map<String, LastMessagePreview> lastMessagesByRoom,
  Map<String, DateTime> lastReadAtByRoom,
) {
  return [
    for (final room in rooms)
      RoomSummary(
        room: room,
        name: buildRoomName(room, members),
        lastMessage: lastMessagesByRoom[room.id],
        hasUnread: isRoomUnread(
          lastMessagesByRoom[room.id]?.createdAt,
          lastReadAtByRoom[room.id],
        ),
      ),
  ];
}

class RawReactionRow {
  const RawReactionRow({
    required this.messageId,
    required this.memberId,
    required this.emoji,
  });

  final String messageId;
  final String memberId;
  final String emoji;
}

/// reactions 행을 메시지id → 이모지별 묶음으로 만든다 (RN fetchReactions의 집계 부분).
/// 이모지 순서는 첫 등장 순서를 유지한다.
Map<String, List<ReactionSummary>> groupReactions(List<RawReactionRow> rows) {
  final byMessage = <String, Map<String, List<String>>>{};
  for (final row in rows) {
    byMessage
        .putIfAbsent(row.messageId, () => {})
        .putIfAbsent(row.emoji, () => [])
        .add(row.memberId);
  }
  return {
    for (final entry in byMessage.entries)
      entry.key: [
        for (final e in entry.value.entries)
          ReactionSummary(emoji: e.key, memberIds: e.value),
      ],
  };
}

/// 반응 목록에서 내가 누른 이모지를 찾는다 (없으면 null).
String? myReactionEmoji(List<ReactionSummary> reactions, String myMemberId) {
  for (final r in reactions) {
    if (r.memberIds.contains(myMemberId)) return r.emoji;
  }
  return null;
}
