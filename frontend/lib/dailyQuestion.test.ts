import { DAILY_QUESTIONS, pickDailyQuestion } from "./dailyQuestion";

describe("pickDailyQuestion", () => {
  it("같은 날짜를 넣으면 같은 질문을 반환한다", () => {
    const a = pickDailyQuestion(new Date(2026, 9, 22));
    const b = pickDailyQuestion(new Date(2026, 9, 22));
    expect(a).toBe(b);
  });

  it("날짜의 일(day) 값으로 로테이션한다", () => {
    expect(pickDailyQuestion(new Date(2026, 0, 1))).toBe(
      DAILY_QUESTIONS[1 % DAILY_QUESTIONS.length]
    );
    expect(pickDailyQuestion(new Date(2026, 0, 2))).toBe(
      DAILY_QUESTIONS[2 % DAILY_QUESTIONS.length]
    );
  });

  it("어떤 날짜를 넣어도 배열 범위 안의 질문을 반환한다", () => {
    for (let day = 1; day <= 31; day++) {
      const question = pickDailyQuestion(new Date(2026, 0, day));
      expect(DAILY_QUESTIONS).toContain(question);
    }
  });
});
