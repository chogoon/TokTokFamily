import 'package:flutter/foundation.dart';

/// 메시지 종류. DB check 제약 `kind in ('text','sticker','system')`과 같다.
enum MessageKind { text, sticker, system }

/// `public.messages` 행 + 보낸 사람 이름. RN `frontend/types/message.ts`의 `Message`에 대응.
/// (Dart/Flutter의 다른 `Message` 타입과 겹치지 않도록 ChatMessage로 이름 붙였다.)
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.kind,
    required this.body,
    required this.isUrgent,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final MessageKind kind;
  final String? body;
  final bool isUrgent;
  final DateTime createdAt;

  bool get isSticker => kind == MessageKind.sticker;

  /// messages 행(REST 조회 또는 Realtime payload의 newRecord)을 변환한다.
  factory ChatMessage.fromRow(
    Map<String, dynamic> row, {
    required String senderName,
  }) {
    return ChatMessage(
      id: row['id'] as String,
      roomId: row['room_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: senderName,
      kind: _parseKind(row['kind']),
      body: row['body'] as String?,
      isUrgent: (row['is_urgent'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static MessageKind _parseKind(Object? value) {
    switch (value) {
      case 'sticker':
        return MessageKind.sticker;
      case 'system':
        return MessageKind.system;
      case 'text':
      default:
        // 알 수 없는 kind는 텍스트로 보여준다 (화면 전체가 깨지지 않도록).
        return MessageKind.text;
    }
  }
}

/// 메시지 하나에 달린 반응을 이모지별로 묶은 결과 (누가 눌렀는지는 memberIds로).
class ReactionSummary {
  const ReactionSummary({required this.emoji, required this.memberIds});

  final String emoji;
  final List<String> memberIds;

  @override
  bool operator ==(Object other) =>
      other is ReactionSummary &&
      other.emoji == emoji &&
      listEquals(other.memberIds, memberIds);

  @override
  int get hashCode => Object.hash(emoji, Object.hashAll(memberIds));

  @override
  String toString() => 'ReactionSummary($emoji, $memberIds)';
}
