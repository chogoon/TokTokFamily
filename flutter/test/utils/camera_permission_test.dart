import 'package:family_toktok/utils/camera_permission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('describeCameraPermissionState (RN cameraPermission.ts 포팅)', () {
    test('허용됐으면 granted', () {
      expect(describeCameraPermissionState(granted: true, canAskAgain: true),
          CameraPermissionState.granted);
      expect(describeCameraPermissionState(granted: true, canAskAgain: false),
          CameraPermissionState.granted);
    });

    test('거부됐지만 다시 물을 수 있으면 can-ask', () {
      expect(describeCameraPermissionState(granted: false, canAskAgain: true),
          CameraPermissionState.canAsk);
    });

    test('거부됐고 다시 물을 수 없으면 blocked (OS 설정으로 안내)', () {
      expect(describeCameraPermissionState(granted: false, canAskAgain: false),
          CameraPermissionState.blocked);
    });
  });

  group('cameraPermissionStateFromStatus (permission_handler 상태 매핑)', () {
    test('granted/limited는 granted', () {
      expect(cameraPermissionStateFromStatus(PermissionStatus.granted),
          CameraPermissionState.granted);
      expect(cameraPermissionStateFromStatus(PermissionStatus.limited),
          CameraPermissionState.granted);
    });

    test('denied(아직 묻지 않음 또는 한 번 거부)는 can-ask', () {
      expect(cameraPermissionStateFromStatus(PermissionStatus.denied),
          CameraPermissionState.canAsk);
    });

    test('permanentlyDenied/restricted는 다이얼로그가 안 뜨므로 blocked', () {
      expect(
          cameraPermissionStateFromStatus(PermissionStatus.permanentlyDenied),
          CameraPermissionState.blocked);
      expect(cameraPermissionStateFromStatus(PermissionStatus.restricted),
          CameraPermissionState.blocked);
    });
  });
}
