import {
  buildWeeklyMoodDays,
  canSeeNote,
  dayOfWeekLabel,
  MOODS,
  shouldNotifyParent,
} from "./moods";

describe("MOODS", () => {
  it("이모지 5종을 프로토타입과 동일한 순서로 정의한다", () => {
    expect(MOODS.map((m) => m.emoji)).toEqual(["😆", "🙂", "😐", "😢", "😠"]);
  });
});

describe("shouldNotifyParent", () => {
  it("슬픔(😢)이면 true", () => {
    expect(shouldNotifyParent("😢")).toBe(true);
  });

  it("화남(😠)이면 true", () => {
    expect(shouldNotifyParent("😠")).toBe(true);
  });

  it.each(["😆", "🙂", "😐"])("%s는 false", (emoji) => {
    expect(shouldNotifyParent(emoji)).toBe(false);
  });
});

describe("canSeeNote", () => {
  it("보호자는 누구의 이유든 볼 수 있다", () => {
    expect(canSeeNote("parent", "parent-1", "kid-1")).toBe(true);
    expect(canSeeNote("parent", "parent-1", "kid-2")).toBe(true);
  });

  it("아이 본인의 이유는 볼 수 있다", () => {
    expect(canSeeNote("kid", "kid-1", "kid-1")).toBe(true);
  });

  it("아이는 다른 형제의 이유를 볼 수 없다", () => {
    expect(canSeeNote("kid", "kid-1", "kid-2")).toBe(false);
  });
});

describe("dayOfWeekLabel", () => {
  it("일요일부터 토요일까지 한글 요일을 반환한다", () => {
    // 2026-10-18 is a Sunday
    expect(dayOfWeekLabel(new Date(2026, 9, 18))).toBe("일");
    expect(dayOfWeekLabel(new Date(2026, 9, 19))).toBe("월");
    expect(dayOfWeekLabel(new Date(2026, 9, 20))).toBe("화");
    expect(dayOfWeekLabel(new Date(2026, 9, 21))).toBe("수");
    expect(dayOfWeekLabel(new Date(2026, 9, 22))).toBe("목");
    expect(dayOfWeekLabel(new Date(2026, 9, 23))).toBe("금");
    expect(dayOfWeekLabel(new Date(2026, 9, 24))).toBe("토");
  });
});

describe("buildWeeklyMoodDays", () => {
  const today = new Date(2026, 9, 22); // 2026-10-22 (목)

  it("오늘을 포함해 7일치 배열을 만든다", () => {
    const result = buildWeeklyMoodDays("kid-1", {}, today);
    expect(result).toHaveLength(7);
  });

  it("날짜는 과거->오늘 오름차순이고 마지막 칸이 오늘이다", () => {
    const result = buildWeeklyMoodDays("kid-1", {}, today);
    expect(result[0].date).toBe("2026-10-16");
    expect(result[6].date).toBe("2026-10-22");
    expect(result[6].isToday).toBe(true);
    expect(result.slice(0, 6).every((d) => !d.isToday)).toBe(true);
  });

  it("오늘 칸의 dayLabel은 '오늘'이고 나머지는 요일 레이블이다", () => {
    const result = buildWeeklyMoodDays("kid-1", {}, today);
    expect(result[6].dayLabel).toBe("오늘");
    expect(result[0].dayLabel).toBe("금"); // 2026-10-16 is Friday
    expect(result[5].dayLabel).toBe("수"); // 2026-10-21 is Wednesday
  });

  it("해당 날짜/멤버의 기분 기록이 있으면 이모지를 채운다", () => {
    const moodsByDate = {
      "2026-10-20": { "kid-1": { emoji: "😆" }, "kid-2": { emoji: "😐" } },
      "2026-10-22": { "kid-1": { emoji: "😢" } },
    };
    const result = buildWeeklyMoodDays("kid-1", moodsByDate, today);
    const oct20 = result.find((d) => d.date === "2026-10-20");
    const oct22 = result.find((d) => d.date === "2026-10-22");
    expect(oct20?.emoji).toBe("😆");
    expect(oct22?.emoji).toBe("😢");
  });

  it("기록이 없는 날짜는 emoji가 null이다", () => {
    const result = buildWeeklyMoodDays("kid-1", {}, today);
    expect(result.every((d) => d.emoji === null)).toBe(true);
  });

  it("다른 멤버의 기록은 섞이지 않는다", () => {
    const moodsByDate = {
      "2026-10-22": { "kid-2": { emoji: "😠" } },
    };
    const result = buildWeeklyMoodDays("kid-1", moodsByDate, today);
    const oct22 = result.find((d) => d.date === "2026-10-22");
    expect(oct22?.emoji).toBeNull();
  });
});
