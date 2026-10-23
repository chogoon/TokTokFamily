import 'package:family_toktok/models/chat_message.dart';
import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/models/room.dart';
import 'package:family_toktok/utils/rooms.dart';
import 'package:flutter_test/flutter_test.dart';

// RN frontend/lib/rooms.test.ts 포팅.
const familyRoom = Room(
  id: 'room-family',
  familyId: 'family-1',
  type: RoomType.family,
  kidMemberId: null,
);

const kidRoom = Room(
  id: 'room-kid-1',
  familyId: 'family-1',
  type: RoomType.kid,
  kidMemberId: 'member-kid-1',
);

const members = [
  Member(
      id: 'member-parent',
      familyId: 'family-1',
      role: MemberRole.parent,
      name: '엄마'),
  Member(
      id: 'member-kid-1',
      familyId: 'family-1',
      role: MemberRole.kid,
      name: '서아',
      avatar: '🐰',
      color: '#FFB547'),
];

DateTime t(String iso) => DateTime.parse(iso);

void main() {
  group('buildRoomName', () {
    test("가족방은 '가족방'으로 표시한다", () {
      expect(buildRoomName(familyRoom, members), '가족방');
    });

    test("1:1방은 '{아이이름}와의 대화'로 표시한다", () {
      expect(buildRoomName(kidRoom, members), '서아와의 대화');
    });

    test('아이 정보를 찾지 못하면 기본 레이블을 쓴다', () {
      const orphan = Room(
          id: 'room-kid-1',
          familyId: 'family-1',
          type: RoomType.kid,
          kidMemberId: 'unknown-member');
      expect(buildRoomName(orphan, members), '1:1 대화');
    });
  });

  group('isRoomUnread', () {
    test('마지막 메시지가 없으면 안읽음이 아니다', () {
      expect(isRoomUnread(null, null), isFalse);
    });

    test('읽은 적이 없고 메시지가 있으면 안읽음이다', () {
      expect(isRoomUnread(t('2026-10-22T10:00:00.000Z'), null), isTrue);
    });

    test('마지막 메시지가 읽음 시각보다 이후면 안읽음이다', () {
      expect(
          isRoomUnread(
              t('2026-10-22T10:00:00.000Z'), t('2026-10-22T09:00:00.000Z')),
          isTrue);
    });

    test('마지막 메시지가 읽음 시각보다 이전이거나 같으면 안읽음이 아니다', () {
      expect(
          isRoomUnread(
              t('2026-10-22T09:00:00.000Z'), t('2026-10-22T10:00:00.000Z')),
          isFalse);
      expect(
          isRoomUnread(
              t('2026-10-22T10:00:00.000Z'), t('2026-10-22T10:00:00.000Z')),
          isFalse);
    });

    test('시간대 표기가 달라도 같은 순간이면 비교가 맞다', () {
      expect(
          isRoomUnread(
              t('2026-10-22T19:00:00+09:00'), t('2026-10-22T10:00:00.000Z')),
          isFalse);
    });
  });

  group('pickLastMessagePerRoom', () {
    test('내림차순 입력에서 방별 첫 행(가장 최신)만 남긴다', () {
      final result = pickLastMessagePerRoom([
        RawMessageRow(
            roomId: 'room-a',
            body: '최신',
            createdAt: t('2026-10-22T10:00:00.000Z')),
        RawMessageRow(
            roomId: 'room-a',
            body: '이전',
            createdAt: t('2026-10-22T09:00:00.000Z')),
        RawMessageRow(
            roomId: 'room-b',
            body: 'b방 메시지',
            createdAt: t('2026-10-22T08:00:00.000Z')),
      ]);

      expect(result, {
        'room-a': LastMessagePreview(
            body: '최신', createdAt: t('2026-10-22T10:00:00.000Z')),
        'room-b': LastMessagePreview(
            body: 'b방 메시지', createdAt: t('2026-10-22T08:00:00.000Z')),
      });
    });

    test('빈 입력이면 빈 맵을 반환한다', () {
      expect(pickLastMessagePerRoom(const []), isEmpty);
    });
  });

  group('buildRoomSummaries', () {
    test('방/이름/마지막 메시지/안읽음 여부를 합성한다', () {
      final summaries = buildRoomSummaries(
        [familyRoom, kidRoom],
        members,
        {
          'room-family': LastMessagePreview(
              body: '안녕', createdAt: t('2026-10-22T10:00:00.000Z')),
        },
        {
          'room-family': t('2026-10-22T09:00:00.000Z'),
          'room-kid-1': t('2026-10-22T09:00:00.000Z'),
        },
      );

      expect(summaries, [
        RoomSummary(
          room: familyRoom,
          name: '가족방',
          lastMessage: LastMessagePreview(
              body: '안녕', createdAt: t('2026-10-22T10:00:00.000Z')),
          hasUnread: true,
        ),
        const RoomSummary(
          room: kidRoom,
          name: '서아와의 대화',
          lastMessage: null,
          hasUnread: false,
        ),
      ]);
    });
  });

  group('nextReactionEmoji', () {
    test('반응 이모지 상수는 프로토타입과 같은 3종이다', () {
      expect(reactionEmojis, ['❤️', '👍', '😂']);
    });

    test('반응이 없던 상태에서 누르면 첫 번째 이모지가 된다', () {
      expect(nextReactionEmoji(reactionEmojis, null), '❤️');
    });

    test('현재 반응의 다음 이모지로 순환한다', () {
      expect(nextReactionEmoji(reactionEmojis, '❤️'), '👍');
      expect(nextReactionEmoji(reactionEmojis, '👍'), '😂');
    });

    test('마지막 이모지에서 한 번 더 누르면 반응 없음(null)으로 돌아간다', () {
      expect(nextReactionEmoji(reactionEmojis, '😂'), isNull);
    });

    test('목록에 없는 이모지가 현재값으로 들어오면 처음부터 순환한다', () {
      expect(nextReactionEmoji(reactionEmojis, '🙂'), '❤️');
    });
  });

  group('groupReactions', () {
    test('반응 행을 메시지id → 이모지별 memberIds로 묶는다 (첫 등장 순서 유지)', () {
      final result = groupReactions(const [
        RawReactionRow(messageId: 'm1', memberId: 'a', emoji: '👍'),
        RawReactionRow(messageId: 'm1', memberId: 'b', emoji: '❤️'),
        RawReactionRow(messageId: 'm1', memberId: 'c', emoji: '👍'),
        RawReactionRow(messageId: 'm2', memberId: 'a', emoji: '😂'),
      ]);

      expect(result, {
        'm1': const [
          ReactionSummary(emoji: '👍', memberIds: ['a', 'c']),
          ReactionSummary(emoji: '❤️', memberIds: ['b']),
        ],
        'm2': const [
          ReactionSummary(emoji: '😂', memberIds: ['a']),
        ],
      });
    });

    test('빈 입력이면 빈 맵', () {
      expect(groupReactions(const []), isEmpty);
    });
  });

  group('myReactionEmoji', () {
    test('내 memberId가 포함된 첫 반응 이모지를 돌려준다', () {
      const reactions = [
        ReactionSummary(emoji: '❤️', memberIds: ['b']),
        ReactionSummary(emoji: '👍', memberIds: ['a', 'me']),
      ];
      expect(myReactionEmoji(reactions, 'me'), '👍');
      expect(myReactionEmoji(reactions, 'nobody'), isNull);
      expect(myReactionEmoji(const [], 'me'), isNull);
    });
  });
}
