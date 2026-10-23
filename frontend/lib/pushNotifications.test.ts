import { getPlatform } from "./pushNotifications";

describe("getPlatform", () => {
  it("ios는 그대로 ios를 반환한다", () => {
    expect(getPlatform("ios")).toBe("ios");
  });

  it("android는 그대로 android를 반환한다", () => {
    expect(getPlatform("android")).toBe("android");
  });

  it("web 등 지원하지 않는 플랫폼은 null을 반환한다", () => {
    expect(getPlatform("web")).toBeNull();
    expect(getPlatform("windows")).toBeNull();
  });
});
