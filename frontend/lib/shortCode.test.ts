import { formatShortCode, isCompleteShortCode, sanitizeShortCodeInput } from "./shortCode";

describe("formatShortCode", () => {
  it("6자리 숫자를 가운데 공백으로 나눠 표시한다", () => {
    expect(formatShortCode("482913")).toBe("482 913");
  });

  it("6자리가 안 채워졌으면 있는 그대로 반환한다", () => {
    expect(formatShortCode("48")).toBe("48");
    expect(formatShortCode("")).toBe("");
  });
});

describe("sanitizeShortCodeInput", () => {
  it("숫자가 아닌 문자를 제거한다", () => {
    expect(sanitizeShortCodeInput("48-29 13")).toBe("482913");
  });

  it("6자리를 넘으면 잘라낸다", () => {
    expect(sanitizeShortCodeInput("1234567890")).toBe("123456");
  });
});

describe("isCompleteShortCode", () => {
  it("정확히 6자리 숫자면 true", () => {
    expect(isCompleteShortCode("482913")).toBe(true);
  });

  it("6자리가 아니면 false", () => {
    expect(isCompleteShortCode("4829")).toBe(false);
    expect(isCompleteShortCode("")).toBe(false);
  });
});
