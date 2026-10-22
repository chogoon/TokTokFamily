import 'package:permission_handler/permission_handler.dart';

// QR 스캔 화면에서 카메라 권한 상태에 따라 어떤 안내/버튼을 보여줄지 결정하는 순수 로직.
// RN `frontend/lib/cameraPermission.ts` 포팅.
// Android에서 사용자가 권한을 거부(특히 "다시 묻지 않음")하면 다시 요청해도 OS가
// 네이티브 다이얼로그를 띄우지 않아 버튼이 "반응 없음"처럼 보인다. 이때는 OS 설정으로 보낸다.

enum CameraPermissionState {
  /// 허용됨 → 카메라 미리보기를 띄운다
  granted,

  /// 아직 묻지 않았거나 한 번 거부 → "카메라 켜기"로 다시 요청
  canAsk,

  /// 다시 물을 수 없음(영구 거부/제한) → "설정에서 카메라 켜기"
  blocked,
}

CameraPermissionState describeCameraPermissionState({
  required bool granted,
  required bool canAskAgain,
}) {
  if (granted) return CameraPermissionState.granted;
  return canAskAgain ? CameraPermissionState.canAsk : CameraPermissionState.blocked;
}

/// permission_handler의 [PermissionStatus]를 3단계 분기로 바꾼다.
/// iOS `restricted`(자녀 보호 기능 등)도 앱에서 다시 물을 수 없으므로 blocked로 본다.
CameraPermissionState cameraPermissionStateFromStatus(PermissionStatus status) {
  return describeCameraPermissionState(
    granted: status.isGranted || status.isLimited,
    canAskAgain: !(status.isPermanentlyDenied || status.isRestricted),
  );
}
