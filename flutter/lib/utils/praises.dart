// 칭찬판 순수 로직(네트워크 없음). RN `frontend/lib/praises.ts`에 대응.
import '../models/praise.dart';

const String defaultGoalText = '목표를 정해주세요';

/// 모은 칭찬 개수가 목표 개수에 도달했는지(이상 포함) 판정한다.
bool isGoalReached(int count, int targetCount) =>
    count >= targetCount && targetCount > 0;

/// 길이 targetCount의 슬롯 리스트. 앞에서 count개는 채워짐(true).
List<bool> buildBoardSlots(int count, int targetCount) =>
    List<bool>.generate(targetCount < 0 ? 0 : targetCount, (i) => i < count);

/// 목표 텍스트 + 진행도(n/target)를 한 줄로 합성한다. 진행도는 target을 넘지 않게 고정한다.
String buildGoalProgressText(String goalText, int count, int targetCount) {
  final shown = count < targetCount ? count : targetCount;
  final trimmed = goalText.trim();
  final text = trimmed.isEmpty ? defaultGoalText : trimmed;
  return '🎯 $targetCount개 모으면: $text ($shown/$targetCount)';
}

/// 칭찬 기록을 최신순으로 정렬한 새 리스트를 돌려준다. 입력은 변경하지 않는다.
List<PraiseEntry> sortPraisesByNewest(List<PraiseEntry> entries) =>
    List.of(entries)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
