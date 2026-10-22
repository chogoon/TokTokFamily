// 대화방 입력창 위에 보이는 빠른 답장 칩 + 스티커 목록.
// family-sns.html 프로토타입의 CHIPS/STICKERS 상수를 그대로 포팅했다.
// kid 칩 중 urgent:true 두 개는 일반 칩과 다르게 "아이 자신의 1:1방"으로
// 바로 전송되는 긴급 버튼으로 동작한다 (app/room/[roomId].tsx 참고).

export interface QuickReply {
  text: string;
  urgent?: boolean;
}

export const KID_QUICK_REPLIES: QuickReply[] = [
  { text: "🏫 학교 끝났어요!" },
  { text: "🏠 집에 도착했어요" },
  { text: "🍙 배고파요" },
  { text: "📚 숙제 다 했어요" },
  { text: "🥰 사랑해요" },
  { text: "🚨 데리러 와주세요", urgent: true },
  { text: "😢 도와주세요", urgent: true },
];

export const PARENT_QUICK_REPLIES: QuickReply[] = [
  { text: "잘 도착했니?" },
  { text: "간식 냉장고에 있어 🍓" },
  { text: "오늘도 최고야 👍" },
  { text: "몇 시에 끝나?" },
  { text: "숙제는 했니?" },
  { text: "곧 집에 갈게!" },
  { text: "사랑해 💕" },
];

export const STICKERS: readonly string[] = [
  "🥰",
  "😆",
  "😭",
  "👍",
  "🎉",
  "💯",
  "🐶",
  "🐱",
  "🍕",
  "🍦",
  "⚽",
  "🌈",
];
