import 'package:permission_handler/permission_handler.dart';

import '../utils/camera_permission.dart';

/// 카메라 권한 확인/요청/설정 열기 경계. 테스트에서는 fake로 대체한다.
abstract class CameraPermissionGateway {
  Future<CameraPermissionState> check();
  Future<CameraPermissionState> request();

  /// OS의 앱 설정 화면을 연다 (영구 거부 시 사용자가 직접 켜야 함).
  Future<void> openSettings();
}

/// permission_handler 기반 실제 구현.
/// mobile_scanner도 시작 시 권한을 요청하지만 "다시 묻지 않음" 여부를 알려주지 않으므로,
/// 스캐너를 띄우기 전에 permission_handler로 3단계 상태를 먼저 판정한다.
class PermissionHandlerCameraGateway implements CameraPermissionGateway {
  const PermissionHandlerCameraGateway();

  @override
  Future<CameraPermissionState> check() async =>
      cameraPermissionStateFromStatus(await Permission.camera.status);

  @override
  Future<CameraPermissionState> request() async =>
      cameraPermissionStateFromStatus(await Permission.camera.request());

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
