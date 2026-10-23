import 'package:family_toktok/models/chat_message.dart';
import 'package:family_toktok/models/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Room.fromRow', () {
    test('가족방 행을 변환한다', () {
      final room = Room.fromRow({
        'id': 'r1',
        'family_id': 'f1',
        'type': 'family',
        'kid_member_id': null,
      });
      expect(room.id, 'r1');
      expect(room.familyId, 'f1');
      expect(room.type, RoomType.family);
      expect(room.isFamily, isTrue);
      expect(room.kidMemberId, isNull);
    });

    test('1:1방 행을 변환한다', () {
      final room = Room.fromRow({
        'id': 'r2',
        'family_id': 'f1',
        'type': 'kid',
        'kid_member_id': 'k1',
      });
      expect(room.type, RoomType.kid);
      expect(room.isFamily, isFalse);
      expect(room.kidMemberId, 'k1');
    });

    test('알 수 없는 type이면 FormatException', () {
      expect(
          () => Room.fromRow({
                'id': 'r',
                'family_id': 'f',
                'type': 'x',
                'kid_member_id': null
              }),
          throwsFormatException);
    });
  });

  group('ChatMessage.fromRow', () {
    test('messages 행 + 보낸 사람 이름을 변환한다', () {
      final m = ChatMessage.fromRow({
        'id': 'm1',
        'room_id': 'r1',
        'sender_id': 'p1',
        'kind': 'sticker',
        'body': '🎉',
        'is_urgent': false,
        'created_at': '2026-10-22T10:00:00.000Z',
      }, senderName: '엄마');
      expect(m.id, 'm1');
      expect(m.roomId, 'r1');
      expect(m.senderId, 'p1');
      expect(m.senderName, '엄마');
      expect(m.kind, MessageKind.sticker);
      expect(m.isSticker, isTrue);
      expect(m.body, '🎉');
      expect(m.isUrgent, isFalse);
      expect(m.createdAt, DateTime.utc(2026, 10, 22, 10));
    });

    test('is_urgent가 없으면 false, kind=text/system 파싱', () {
      final m = ChatMessage.fromRow({
        'id': 'm2',
        'room_id': 'r1',
        'sender_id': 'k1',
        'kind': 'system',
        'body': null,
        'created_at': '2026-10-22T10:00:00Z',
      }, senderName: '가족');
      expect(m.kind, MessageKind.system);
      expect(m.body, isNull);
      expect(m.isUrgent, isFalse);
    });
  });
}
