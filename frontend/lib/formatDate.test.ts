import { formatDate } from "./formatDate";

describe("formatDate", () => {
  it("formats a date as YYYY-MM-DD", () => {
    expect(formatDate(new Date(2026, 0, 5))).toBe("2026-01-05");
  });
});
