// 가족방 상단 "오늘의 가족 질문" 배너용 순수 로직. RN `frontend/lib/dailyQuestion.ts` 포팅.
// daily_questions 테이블은 authenticated insert 정책이 없어(service-role 전용) 쓰지 않고,
// 프로토타입처럼 클라이언트에 질문 목록을 두고 날짜로 로테이션한다 (네트워크 호출 없음).

const dailyQuestions = <String>[
  '오늘 학교에서 가장 재밌었던 일은?',
  '오늘 점심 반찬 중에 뭐가 제일 맛있었어?',
  '요즘 제일 친한 친구는 누구야?',
  '만약 하루 동안 동물이 된다면 뭐가 되고 싶어?',
  '이번 주말에 가족이랑 뭐 하고 싶어?',
  '오늘 누군가를 도와준 일이 있어?',
  '형제·자매에게 고마웠던 일이 있다면?',
];

/// 날짜의 '일(day)' 값(로컬 시간 기준)으로 오늘의 질문을 고른다.
String pickDailyQuestion(DateTime date) =>
    dailyQuestions[date.day % dailyQuestions.length];
