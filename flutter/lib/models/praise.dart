/// `public.praise_boards` / `public.praises` 행. RN `frontend/types/praise.ts`에 대응.
enum PraiseBoardStatus { active, done }

class PraiseBoard {
  const PraiseBoard({
    required this.id,
    required this.kidMemberId,
    required this.familyId,
    required this.goalText,
    required this.targetCount,
    required this.status,
  });

  final String id;
  final String kidMemberId;
  final String familyId;
  final String goalText;
  final int targetCount;
  final PraiseBoardStatus status;

  factory PraiseBoard.fromRow(Map<String, dynamic> row) {
    return PraiseBoard(
      id: row['id'] as String,
      kidMemberId: row['kid_member_id'] as String,
      familyId: row['family_id'] as String,
      goalText: row['goal_text'] as String,
      targetCount: (row['target_count'] as num).toInt(),
      status: _parseStatus(row['status']),
    );
  }

  static PraiseBoardStatus _parseStatus(Object? value) {
    switch (value) {
      case 'active':
        return PraiseBoardStatus.active;
      case 'done':
        return PraiseBoardStatus.done;
      default:
        throw FormatException('unknown praise board status: $value');
    }
  }
}

class PraiseEntry {
  const PraiseEntry({
    required this.id,
    required this.boardId,
    required this.giverId,
    required this.giverName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String boardId;
  final String giverId;

  /// members에서 채운 준 사람 이름 (못 찾으면 "가족").
  final String giverName;
  final String? text;
  final DateTime createdAt;

  factory PraiseEntry.fromRow(Map<String, dynamic> row,
      {required String giverName}) {
    return PraiseEntry(
      id: row['id'] as String,
      boardId: row['board_id'] as String,
      giverId: row['giver_id'] as String,
      giverName: giverName,
      text: row['text'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
