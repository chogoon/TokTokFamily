// family-sns.html 프로토타입의 PALETTE/AVATARS를 그대로 가져왔다.
// backend/src/lib/kidPalette.ts에도 같은 목록이 있다 — 공유 패키지를 만들 규모가
// 아니라서 작은 상수 목록을 양쪽에 복제했다. 바꿀 때는 두 곳 다 맞춘다.
export const KID_COLORS = [
  "#FFB547",
  "#6BCB77",
  "#B28DFF",
  "#FF9F68",
  "#4FC3C7",
  "#F48FB1",
  "#9CCC65",
] as const;

export const KID_AVATARS = [
  "🐣",
  "🦖",
  "🐰",
  "🦊",
  "🐼",
  "🐯",
  "🐨",
  "🦄",
  "🐸",
  "🐧",
] as const;
