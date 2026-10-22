import { describeCameraPermissionState } from "./cameraPermission";

describe("describeCameraPermissionState", () => {
  it("권한이 허용됐으면 'granted'를 반환한다", () => {
    expect(
      describeCameraPermissionState({ granted: true, canAskAgain: true })
    ).toBe("granted");
  });

  it("허용되지 않았지만 다시 물어볼 수 있으면 'can-ask'를 반환한다", () => {
    expect(
      describeCameraPermissionState({ granted: false, canAskAgain: true })
    ).toBe("can-ask");
  });

  it("허용되지 않았고 다시 물어볼 수도 없으면(OS가 다이얼로그를 막음) 'blocked'를 반환한다", () => {
    expect(
      describeCameraPermissionState({ granted: false, canAskAgain: false })
    ).toBe("blocked");
  });

  it("granted가 true면 canAskAgain 값과 무관하게 'granted'를 반환한다", () => {
    expect(
      describeCameraPermissionState({ granted: true, canAskAgain: false })
    ).toBe("granted");
  });
});
