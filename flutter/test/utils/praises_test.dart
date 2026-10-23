import 'package:family_toktok/models/praise.dart';
import 'package:family_toktok/utils/praises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isGoalReached', () {
    test('count가 target보다 작으면 false', () {
      expect(isGoalReached(3, 10), isFalse);
    });
    test('count가 target과 같으면 true', () {
      expect(isGoalReached(10, 10), isTrue);
    });
    test('count가 target보다 크면 true', () {
      expect(isGoalReached(12, 10), isTrue);
    });
    test('count=0이면 false', () {
      expect(isGoalReached(0, 10), isFalse);
    });
    test('target이 0이면 false', () {
      expect(isGoalReached(0, 0), isFalse);
    });
  });

  group('buildBoardSlots', () {
    test('count=0이면 전부 false', () {
      expect(buildBoardSlots(0, 10), List.filled(10, false));
    });
    test('count가 target보다 작으면 앞에서 count개만 true', () {
      final slots = buildBoardSlots(3, 10);
      expect(slots, hasLength(10));
      expect(slots.sublist(0, 3), [true, true, true]);
      expect(slots.sublist(3), List.filled(7, false));
    });
    test('count=target이면 전부 true', () {
      expect(buildBoardSlots(10, 10), List.filled(10, true));
    });
    test('count가 target을 초과해도 길이는 target만큼이고 전부 true', () {
      final slots = buildBoardSlots(12, 10);
      expect(slots, hasLength(10));
      expect(slots, List.filled(10, true));
    });
    test('target이 0이면 빈 리스트', () {
      expect(buildBoardSlots(0, 0), isEmpty);
    });
    test('target이 음수여도 빈 리스트', () {
      expect(buildBoardSlots(0, -1), isEmpty);
    });
  });

  group('buildGoalProgressText', () {
    test('목표 텍스트와 진행도를 n/target 형태로 보여준다', () {
      expect(buildGoalProgressText('보드게임 사기', 3, 10),
          '🎯 10개 모으면: 보드게임 사기 (3/10)');
    });
    test('count가 target을 초과해도 진행도는 target으로 고정한다', () {
      expect(buildGoalProgressText('보드게임 사기', 12, 10),
          '🎯 10개 모으면: 보드게임 사기 (10/10)');
    });
    test('goalText가 비어있으면 기본 안내문을 쓴다', () {
      expect(buildGoalProgressText('', 0, 10),
          '🎯 10개 모으면: $defaultGoalText (0/10)');
      expect(defaultGoalText, '목표를 정해주세요');
    });
    test('goalText가 공백뿐이면 기본 안내문, 앞뒤 공백은 잘라낸다', () {
      expect(
          buildGoalProgressText('   ', 0, 10), '🎯 10개 모으면: 목표를 정해주세요 (0/10)');
      expect(buildGoalProgressText('  레고  ', 1, 10), '🎯 10개 모으면: 레고 (1/10)');
    });
  });

  group('sortPraisesByNewest', () {
    final base = PraiseEntry(
      id: 'p1',
      boardId: 'board-1',
      giverId: 'member-parent',
      giverName: '엄마',
      text: '숙제를 혼자 했어요',
      createdAt: DateTime.parse('2026-10-20T09:00:00.000Z'),
    );
    PraiseEntry at(String id, String iso) => PraiseEntry(
          id: id,
          boardId: base.boardId,
          giverId: base.giverId,
          giverName: base.giverName,
          text: base.text,
          createdAt: DateTime.parse(iso),
        );

    test('createdAt 내림차순으로 정렬한다', () {
      final older = at('p-older', '2026-10-19T09:00:00.000Z');
      final newer = at('p-newer', '2026-10-21T09:00:00.000Z');
      final result = sortPraisesByNewest([base, older, newer]);
      expect(result.map((p) => p.id), ['p-newer', 'p1', 'p-older']);
    });
    test('빈 입력이면 빈 리스트', () {
      expect(sortPraisesByNewest(const []), isEmpty);
    });
    test('원본 리스트를 변경하지 않고 새 리스트를 돌려준다', () {
      final older = at('p-older', '2026-10-19T09:00:00.000Z');
      final list = [older, base];
      final result = sortPraisesByNewest(list);
      expect(list.map((p) => p.id), ['p-older', 'p1']);
      expect(identical(result, list), isFalse);
    });
    test('불변 리스트를 받아도 동작한다', () {
      final older = at('p-older', '2026-10-19T09:00:00.000Z');
      final result = sortPraisesByNewest(List.unmodifiable([older, base]));
      expect(result.map((p) => p.id), ['p1', 'p-older']);
    });
  });
}
