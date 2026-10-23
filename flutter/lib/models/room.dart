/// `public.rooms` 행. RN `frontend/types/room.ts`의 `Room`에 대응.
enum RoomType { family, kid }

class Room {
  const Room({
    required this.id,
    required this.familyId,
    required this.type,
    required this.kidMemberId,
  });

  final String id;
  final String familyId;
  final RoomType type;

  /// 1:1방(type=kid)의 아이 member id. 가족방이면 null.
  final String? kidMemberId;

  bool get isFamily => type == RoomType.family;

  factory Room.fromRow(Map<String, dynamic> row) {
    return Room(
      id: row['id'] as String,
      familyId: row['family_id'] as String,
      type: _parseType(row['type']),
      kidMemberId: row['kid_member_id'] as String?,
    );
  }

  static RoomType _parseType(Object? value) {
    switch (value) {
      case 'family':
        return RoomType.family;
      case 'kid':
        return RoomType.kid;
      default:
        throw FormatException('unknown room type: $value');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Room &&
      other.id == id &&
      other.familyId == familyId &&
      other.type == type &&
      other.kidMemberId == kidMemberId;

  @override
  int get hashCode => Object.hash(id, familyId, type, kidMemberId);
}

/// 방 목록 카드에 쓰는 마지막 메시지 미리보기.
class LastMessagePreview {
  const LastMessagePreview({required this.body, required this.createdAt});

  final String? body;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is LastMessagePreview &&
      other.body == body &&
      other.createdAt.isAtSameMomentAs(createdAt);

  @override
  int get hashCode => Object.hash(body, createdAt.microsecondsSinceEpoch);

  @override
  String toString() => 'LastMessagePreview($body, $createdAt)';
}

/// 방 목록 화면용 요약. RN `RoomSummary extends Room`에 대응 (Dart에서는 상속 대신 [room]을 감싼다).
class RoomSummary {
  const RoomSummary({
    required this.room,
    required this.name,
    required this.lastMessage,
    required this.hasUnread,
  });

  final Room room;

  /// 방 이름 (가족방: "가족방", 1:1방: "{아이이름}와의 대화")
  final String name;
  final LastMessagePreview? lastMessage;
  final bool hasUnread;

  String get id => room.id;

  @override
  bool operator ==(Object other) =>
      other is RoomSummary &&
      other.room == room &&
      other.name == name &&
      other.lastMessage == lastMessage &&
      other.hasUnread == hasUnread;

  @override
  int get hashCode => Object.hash(room, name, lastMessage, hasUnread);

  @override
  String toString() =>
      'RoomSummary(${room.id}, $name, $lastMessage, unread=$hasUnread)';
}
