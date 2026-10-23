import 'package:family_toktok/utils/push_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('devicePlatformFromOsName', () {
    test('ios는 DevicePlatform.ios', () {
      expect(devicePlatformFromOsName('ios'), DevicePlatform.ios);
    });

    test('android는 DevicePlatform.android', () {
      expect(devicePlatformFromOsName('android'), DevicePlatform.android);
    });

    test('devices.platform check 제약이 허용하지 않는 OS는 null', () {
      for (final os in ['macos', 'windows', 'linux', 'fuchsia', 'web', '']) {
        expect(devicePlatformFromOsName(os), isNull, reason: os);
      }
    });
  });

  test('DevicePlatform.value는 devices.platform 컬럼 값과 같다', () {
    expect(DevicePlatform.ios.value, 'ios');
    expect(DevicePlatform.android.value, 'android');
  });

  test('pushProviderFcm은 devices.provider check 제약의 fcm 값', () {
    expect(pushProviderFcm, 'fcm');
  });
}
