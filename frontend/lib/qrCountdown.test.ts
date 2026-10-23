import { formatCountdown, remainingSeconds } from "./qrCountdown";

describe("remainingSeconds", () => {
  it("만료 시각까지 남은 초를 반환한다", () => {
    const now = new Date(2026, 9, 22, 12, 0, 0);
    const expiresAt = new Date(2026, 9, 22, 12, 1, 30).toISOString();
    expect(remainingSeconds(expiresAt, now)).toBe(90);
  });

  it("이미 만료됐으면 0을 반환한다 (음수 금지)", () => {
    const now = new Date(2026, 9, 22, 12, 5, 0);
    const expiresAt = new Date(2026, 9, 22, 12, 0, 0).toISOString();
    expect(remainingSeconds(expiresAt, now)).toBe(0);
  });
});

describe("formatCountdown", () => {
  it("90초를 1:30으로 표시한다", () => {
    expect(formatCountdown(90)).toBe("1:30");
  });

  it("5초를 0:05로 표시한다 (초는 2자리 패딩)", () => {
    expect(formatCountdown(5)).toBe("0:05");
  });

  it("0초를 0:00으로 표시한다", () => {
    expect(formatCountdown(0)).toBe("0:00");
  });

  it("120초(정확히 2분)를 2:00으로 표시한다", () => {
    expect(formatCountdown(120)).toBe("2:00");
  });
});
