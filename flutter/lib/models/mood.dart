/// 기분 모델. RN `frontend/types/mood.ts`에 대응.
///
/// 이모지(`moods`)는 가족 전체 공개, 이유(`mood_notes`)는 본인+보호자만 볼 수 있다
/// (RLS `mood_notes_select`가 1차로 거르고, 화면은 `canSeeNote`로 한 번 더 확인한다).
library;

/// 기분 하나(이모지 + 이유).
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.memberId,
    required this.date,
    required this.emoji,
    this.note,
  });

  final String id;
  final String memberId;

  /// YYYY-MM-DD (로컬 날짜)
  final String date;
  final String emoji;
  final String? note;
}

/// 오늘 가족 전체 기분판의 한 줄. emoji는 전체 공개, note는 canSeeNote로 가려야 한다.
class FamilyTodayMood {
  const FamilyTodayMood({
    required this.memberId,
    required this.date,
    required this.emoji,
    this.note,
  });

  final String memberId;
  final String date;
  final String? emoji;
  final String? note;
}

/// 주간 기록 카드의 하루 칸.
class WeeklyMoodDay {
  const WeeklyMoodDay({
    required this.date,
    required this.dayLabel,
    required this.emoji,
    required this.note,
    required this.isToday,
  });

  /// YYYY-MM-DD
  final String date;

  /// "오늘" 또는 요일(일~토)
  final String dayLabel;
  final String? emoji;
  final String? note;
  final bool isToday;
}
