// 푸시 토큰 등록의 순수 로직. RN `frontend/lib/pushNotifications.ts`의 getPlatform 포팅.
// 네이티브(Firebase) 호출은 `services/push_notifications_service.dart`로 분리해, 여기는
// 네트워크/네이티브 모듈 없이 테스트한다.

/// devices.platform 컬럼 값 (check 제약: ios/android만 허용).
enum DevicePlatform {
  ios('ios'),
  android('android');

  const DevicePlatform(this.value);

  final String value;
}

/// devices.provider 컬럼 값. Flutter는 Expo가 아니라 FCM 네이티브 토큰을 발급받으므로
/// 반드시 'fcm'으로 등록해야 backend(`pushDispatch.ts`)가 Firebase Admin SDK로 발송한다.
/// (컬럼 default가 'expo'라 빠뜨리면 Expo Push API로 잘못 발송된다.)
const pushProviderFcm = 'fcm';

/// `Platform.operatingSystem` 문자열을 devices.platform 값으로 매핑한다.
/// 지원하지 않는 플랫폼(web/desktop 등)이면 null.
DevicePlatform? devicePlatformFromOsName(String osName) {
  switch (osName) {
    case 'ios':
      return DevicePlatform.ios;
    case 'android':
      return DevicePlatform.android;
    default:
      return null;
  }
}
