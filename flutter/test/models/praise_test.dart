import 'package:family_toktok/models/praise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PraiseBoard.fromRow: snake_case 행 변환', () {
    final board = PraiseBoard.fromRow({
      'id': 'b1',
      'kid_member_id': 'k1',
      'family_id': 'f1',
      'goal_text': '보드게임',
      'target_count': 10,
      'status': 'active',
    });
    expect(board.id, 'b1');
    expect(board.kidMemberId, 'k1');
    expect(board.familyId, 'f1');
    expect(board.goalText, '보드게임');
    expect(board.targetCount, 10);
    expect(board.status, PraiseBoardStatus.active);
    expect(
        PraiseBoard.fromRow({
          'id': 'b2',
          'kid_member_id': 'k1',
          'family_id': 'f1',
          'goal_text': '',
          'target_count': 10,
          'status': 'done',
        }).status,
        PraiseBoardStatus.done);
  });

  test('PraiseBoard.fromRow: 알 수 없는 status면 FormatException', () {
    expect(
        () => PraiseBoard.fromRow({
              'id': 'b1',
              'kid_member_id': 'k1',
              'family_id': 'f1',
              'goal_text': '',
              'target_count': 10,
              'status': 'weird',
            }),
        throwsFormatException);
  });

  test('PraiseEntry.fromRow: 준 사람 이름은 밖에서 채운다, text는 null 허용', () {
    final entry = PraiseEntry.fromRow({
      'id': 'p1',
      'board_id': 'b1',
      'giver_id': 'm1',
      'text': null,
      'created_at': '2026-10-20T09:00:00Z',
    }, giverName: '엄마');
    expect(entry.id, 'p1');
    expect(entry.boardId, 'b1');
    expect(entry.giverId, 'm1');
    expect(entry.giverName, '엄마');
    expect(entry.text, isNull);
    expect(entry.createdAt, DateTime.utc(2026, 10, 20, 9));
  });
}
