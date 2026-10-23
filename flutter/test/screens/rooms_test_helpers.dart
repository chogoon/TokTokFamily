import 'package:family_toktok/models/chat_message.dart';
import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/models/room.dart';
import 'package:family_toktok/services/rooms_service.dart';

const mom =
    Member(id: 'p1', familyId: 'f1', role: MemberRole.parent, name: '엄마');
const harin = Member(
    id: 'k1', familyId: 'f1', role: MemberRole.kid, name: '하린', avatar: '🐰');

const familyRoom =
    Room(id: 'rf', familyId: 'f1', type: RoomType.family, kidMemberId: null);
const harinRoom =
    Room(id: 'rk', familyId: 'f1', type: RoomType.kid, kidMemberId: 'k1');

ChatMessage msg(
  String id, {
  String roomId = 'rf',
  String senderId = 'k1',
  String senderName = '하린',
  MessageKind kind = MessageKind.text,
  String? body = '안녕',
  bool isUrgent = false,
}) =>
    ChatMessage(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      kind: kind,
      body: body,
      isUrgent: isUrgent,
      createdAt: DateTime(2026, 10, 22, 15, 4),
    );

class SentMessage {
  SentMessage(this.roomId, this.body, this.isUrgent);
  final String roomId;
  final String body;
  final bool isUrgent;
}

/// 화면 테스트용 가짜 RoomsService. Realtime 이벤트는 [emitMessage]/[emitReactionChange]로 흉내 낸다.
class FakeRoomsService implements RoomsService {
  List<RoomSummary> summaries = const [];
  Map<String, Room> rooms = {'rf': familyRoom, 'rk': harinRoom};
  Map<String, List<ChatMessage>> messagesByRoom = {};
  Map<String, List<ReactionSummary>> reactions = {};
  String? myKidRoomId = 'rk';
  Object? sendError;

  final sent = <SentMessage>[];
  final stickersSent = <(String, String)>[];
  final toggles = <(String, String?, String?)>[];
  final markedRead = <String>[];
  int fetchRoomsCalls = 0;
  int fetchReactionsCalls = 0;
  int kidRoomLookups = 0;

  final _messageListeners = <String, List<void Function(ChatMessage)>>{};
  final _reactionListeners = <void Function()>[];
  int activeMessageSubscriptions = 0;

  void emitMessage(ChatMessage m) {
    for (final l in List.of(_messageListeners[m.roomId] ?? const [])) {
      l(m);
    }
  }

  void emitReactionChange() {
    for (final l in List.of(_reactionListeners)) {
      l();
    }
  }

  @override
  Future<List<RoomSummary>> fetchRooms() async {
    fetchRoomsCalls++;
    return summaries;
  }

  @override
  Future<Room?> fetchRoomById(String roomId) async => rooms[roomId];

  @override
  Future<List<ChatMessage>> fetchMessages(String roomId) async =>
      List.of(messagesByRoom[roomId] ?? const []);

  @override
  Future<void> sendMessage(String roomId, String body,
      {bool isUrgent = false}) async {
    if (sendError != null) throw sendError!;
    sent.add(SentMessage(roomId, body, isUrgent));
  }

  @override
  Future<void> sendSticker(String roomId, String emoji) async {
    stickersSent.add((roomId, emoji));
  }

  @override
  Future<String?> fetchMyKidRoomId() async {
    kidRoomLookups++;
    return myKidRoomId;
  }

  @override
  Future<Map<String, List<ReactionSummary>>> fetchReactions(
      List<String> messageIds) async {
    fetchReactionsCalls++;
    return {
      for (final id in messageIds)
        if (reactions[id] != null) id: reactions[id]!,
    };
  }

  @override
  Future<void> toggleReaction(
      String messageId, String? currentEmoji, String? nextEmoji) async {
    toggles.add((messageId, currentEmoji, nextEmoji));
  }

  @override
  Future<void> markRoomRead(String roomId) async => markedRead.add(roomId);

  @override
  Unsubscribe subscribeToMessages(
      String roomId, void Function(ChatMessage message) onInsert) {
    _messageListeners.putIfAbsent(roomId, () => []).add(onInsert);
    activeMessageSubscriptions++;
    return () {
      _messageListeners[roomId]?.remove(onInsert);
      activeMessageSubscriptions--;
    };
  }

  @override
  Unsubscribe subscribeToReactions(
      List<String> messageIds, void Function() onChange) {
    _reactionListeners.add(onChange);
    return () => _reactionListeners.remove(onChange);
  }
}
