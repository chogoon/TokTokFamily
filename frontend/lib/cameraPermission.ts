// scan-qr 화면에서 카메라 권한 상태에 따라 어떤 안내/버튼을 보여줄지 결정하는 순수 로직.
// expo-camera의 PermissionResponse(granted, canAskAgain)를 받아 분기한다.
// Android에서 사용자가 권한을 거부(특히 "다시 묻지 않음")하면 canAskAgain이 false가 되고,
// 이 경우 requestPermission()을 다시 불러도 OS가 네이티브 다이얼로그를 띄우지 않아
// 버튼이 "반응 없음"처럼 보인다. 이때는 OS 설정 화면으로 보내야 한다.

export type CameraPermissionState = "granted" | "can-ask" | "blocked";

export function describeCameraPermissionState(permission: {
  granted: boolean;
  canAskAgain: boolean;
}): CameraPermissionState {
  if (permission.granted) {
    return "granted";
  }
  return permission.canAskAgain ? "can-ask" : "blocked";
}
