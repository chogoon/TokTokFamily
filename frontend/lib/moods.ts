// services/moods.ts가 쓰는 순수 로직(네트워크 없음)만 모은다.
// Supabase 클라이언트(services/supabase.ts)를 import하지 않아야 Jest에서
// AsyncStorage 네이티브 모듈 없이도 테스트할 수 있다.
import { formatDate } from "./formatDate";
import { WeeklyMoodDay } from "../types/mood";

/** family-sns.html의 MOODS 배열(이모지 5종 + 라벨) 그대로. */
export const MOODS: { emoji: string; label: string }[] = [
  { emoji: "😆", label: "신나" },
  { emoji: "🙂", label: "좋아" },
  { emoji: "😐", label: "그냥" },
  { emoji: "😢", label: "슬퍼" },
  { emoji: "😠", label: "화나" },
];

const SAD_OR_ANGRY_EMOJIS = ["😢", "😠"];

const DAY_OF_WEEK_LABELS = ["일", "월", "화", "수", "목", "금", "토"];

/** 아이가 슬프거나 화난 기분을 고르면 보호자의 1:1방으로 알려야 한다. */
export function shouldNotifyParent(emoji: string): boolean {
  return SAD_OR_ANGRY_EMOJIS.includes(emoji);
}

/** 기분 이유(note)는 작성한 본인이거나 보호자만 볼 수 있다. 다른 형제는 볼 수 없다. */
export function canSeeNote(
  viewerRole: "parent" | "kid",
  viewerMemberId: string,
  moodOwnerMemberId: string
): boolean {
  return viewerRole === "parent" || viewerMemberId === moodOwnerMemberId;
}

/** 날짜의 요일 레이블(일~토)을 반환한다. */
export function dayOfWeekLabel(date: Date): string {
  return DAY_OF_WEEK_LABELS[date.getDay()];
}

/**
 * today를 포함한 최근 7일을 날짜 오름차순(과거 -> 오늘)으로 만든다.
 * moodsByDate: { "2026-10-22": { "<memberId>": { emoji: "🙂" }, ... }, ... }
 * 오늘 칸은 dayLabel이 "오늘"이고, 그 외는 요일(일~토)로 표시한다.
 */
export function buildWeeklyMoodDays(
  targetMemberId: string,
  moodsByDate: Record<string, Record<string, { emoji: string; note?: string | null }>>,
  today: Date
): WeeklyMoodDay[] {
  const days: WeeklyMoodDay[] = [];
  for (let i = 6; i >= 0; i -= 1) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    const dateKey = formatDate(date);
    const entry = moodsByDate[dateKey]?.[targetMemberId];
    const isToday = i === 0;
    days.push({
      date: dateKey,
      dayLabel: isToday ? "오늘" : dayOfWeekLabel(date),
      emoji: entry?.emoji ?? null,
      note: entry?.note ?? null,
      isToday,
    });
  }
  return days;
}
