/** 기분 하나(이모지 + 이유)를 나타낸다. note는 본인+보호자만 볼 수 있다 (RLS + canSeeNote). */
export interface MoodEntry {
  id: string;
  memberId: string;
  date: string; // YYYY-MM-DD (로컬 날짜)
  emoji: string;
  note: string | null;
}

/** 오늘 가족 전체 기분판에 쓰는 한 줄. emoji는 전체 공개, note는 canSeeNote로 가려야 한다. */
export interface FamilyTodayMood {
  memberId: string;
  date: string;
  emoji: string | null;
  note: string | null;
}

/** 주간 기록 카드의 하루 칸. */
export interface WeeklyMoodDay {
  date: string; // YYYY-MM-DD
  dayLabel: string; // "오늘" 또는 요일(일~토)
  emoji: string | null;
  note: string | null;
  isToday: boolean;
}
