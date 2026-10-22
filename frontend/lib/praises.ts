// services/praises.ts가 쓰는 순수 로직(네트워크 없음)만 모은다.
// Supabase 클라이언트(services/supabase.ts)를 import하지 않아야 Jest에서
// AsyncStorage 네이티브 모듈 없이도 테스트할 수 있다.
import { PraiseEntry } from "../types/praise";

export const DEFAULT_GOAL_TEXT = "목표를 정해주세요";

/** 모은 칭찬 개수가 목표 개수에 도달했는지(이상 포함) 판정한다. */
export function isGoalReached(count: number, targetCount: number): boolean {
  return count >= targetCount && targetCount > 0;
}

/** 길이 targetCount의 슬롯 배열을 만든다. 앞에서 count개는 채워짐(true)으로 표시한다. */
export function buildBoardSlots(count: number, targetCount: number): boolean[] {
  return Array.from({ length: Math.max(targetCount, 0) }, (_, i) => i < count);
}

/** 목표 텍스트 + 진행도(n/target)를 한 줄로 합성한다. 진행도는 target을 넘지 않게 고정한다. */
export function buildGoalProgressText(
  goalText: string,
  count: number,
  targetCount: number
): string {
  const shown = Math.min(count, targetCount);
  const text = goalText.trim() || DEFAULT_GOAL_TEXT;
  return `🎯 ${targetCount}개 모으면: ${text} (${shown}/${targetCount})`;
}

/** 칭찬 기록을 최신순으로 정렬한다. 입력 배열은 변경하지 않는다. */
export function sortPraisesByNewest(entries: PraiseEntry[]): PraiseEntry[] {
  return [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );
}
