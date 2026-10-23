// 가족방 상단에 표시하는 "오늘의 가족 질문" 배너용 순수 로직.
// daily_questions 테이블은 authenticated insert 정책이 없어(service-role 전용,
// ADR-004 범위 밖) 이 기능에서는 쓰지 않는다. 프로토타입(family-sns.html의
// QUESTIONS/renderChat)처럼 클라이언트에 질문 목록을 하드코딩하고 날짜로
// 로테이션한다. DB 저장이 없으므로 네트워크 호출이 전혀 필요 없다.

export const DAILY_QUESTIONS: readonly string[] = [
  "오늘 학교에서 가장 재밌었던 일은?",
  "오늘 점심 반찬 중에 뭐가 제일 맛있었어?",
  "요즘 제일 친한 친구는 누구야?",
  "만약 하루 동안 동물이 된다면 뭐가 되고 싶어?",
  "이번 주말에 가족이랑 뭐 하고 싶어?",
  "오늘 누군가를 도와준 일이 있어?",
  "형제·자매에게 고마웠던 일이 있다면?",
];

/**
 * 날짜의 '일(day)' 값을 기준으로 오늘의 질문을 고른다.
 * 같은 날짜를 넣으면 항상 같은 질문이 나오고, 배열 범위를 벗어나지 않는다.
 */
export function pickDailyQuestion(date: Date): string {
  const index = date.getDate() % DAILY_QUESTIONS.length;
  return DAILY_QUESTIONS[index];
}
