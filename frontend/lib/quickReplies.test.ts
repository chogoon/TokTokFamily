import { KID_QUICK_REPLIES, PARENT_QUICK_REPLIES } from "./quickReplies";

describe("KID_QUICK_REPLIES", () => {
  it("긴급 칩은 정확히 2개다 (데리러 와주세요 / 도와주세요)", () => {
    const urgentChips = KID_QUICK_REPLIES.filter((chip) => chip.urgent);
    expect(urgentChips).toHaveLength(2);
    expect(urgentChips.map((c) => c.text)).toEqual([
      "🚨 데리러 와주세요",
      "😢 도와주세요",
    ]);
  });
});

describe("PARENT_QUICK_REPLIES", () => {
  it("부모 칩에는 긴급 칩이 없다", () => {
    expect(PARENT_QUICK_REPLIES.every((chip) => !chip.urgent)).toBe(true);
  });
});
