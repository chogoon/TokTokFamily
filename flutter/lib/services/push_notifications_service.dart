import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../utils/push_notifications.dart';
import 'devices_service.dart';

/// Firebase(네이티브) 호출 경계. 테스트에서는 fake로 대체한다
/// (RN이 expo-notifications 네이티브 모듈을 테스트하지 않는 것과 같은 원칙).
abstract class PushMessagingGateway {
  /// Firebase를 쓸 수 있으면 true. 설정 파일(google-services.json /
  /// GoogleService-Info.plist)이 없으면 false 또는 throw.
  Future<bool> initialize();
  Future<AuthorizationStatus> requestPermission();
  Future<String?> getToken();
  Future<void> setForegroundPresentationOptions();
}

/// firebase_core / firebase_messaging 기반 실제 구현.
class FirebasePushMessagingGateway implements PushMessagingGateway {
  FirebasePushMessagingGateway();

  Future<bool>? _initialized;

  /// 옵션 없이 initializeApp을 부르면 네이티브 설정 파일에서 읽는다. 파일이 없으면
  /// 예외가 나므로 false로 바꾸고, 결과를 캐시해 매 로그인마다 다시 시도하지 않는다.
  @override
  Future<bool> initialize() => _initialized ??= _initialize();

  Future<bool> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return true;
    } catch (e) {
      debugPrint('[push] Firebase 설정이 없어 푸시 등록을 건너뜁니다: $e');
      return false;
    }
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    // Android 13+는 POST_NOTIFICATIONS 런타임 권한 다이얼로그, iOS는 알림 권한 다이얼로그.
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus;
  }

  // firebase_messaging 17은 getToken()을 deprecated하고 FID 기반 register()/onRegistered를
  // 권장하지만, backend(`firebaseAdminPush.ts`)는 Admin SDK `TokenMessage.token`으로
  // FCM registration token에 발송한다. FID는 이 계약과 다른 값이라 getToken()을 유지한다.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Future<void> setForegroundPresentationOptions() =>
      // iOS 전용 API (Android에서는 no-op). 포그라운드에서도 배너가 보이게 한다.
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: false,
        sound: false,
      );
}

/// 권한 요청 + FCM 토큰 발급. RN `lib/pushNotifications.ts`의 네이티브 호출부에 대응.
/// 알림은 선택 기능이라 어떤 실패도 throw하지 않고 null로 바꾼다.
class PushNotificationsService {
  /// [osName]은 `Platform.operatingSystem` (web이면 null).
  PushNotificationsService(this._gateway, {required this.osName});

  final PushMessagingGateway _gateway;
  final String? osName;

  DevicePlatform? get platform =>
      osName == null ? null : devicePlatformFromOsName(osName!);

  /// 앱 시작 시 한 번 호출. 포그라운드에서도 알림 배너가 보이도록 설정한다.
  /// Android는 FCM이 백그라운드 알림을 기본 채널(fcm_fallback_notification_channel)로
  /// 표시하므로 별도 채널 생성이 필요 없다. Android 포그라운드 표시는 별도 로컬 알림
  /// 패키지가 필요해 이번 범위에서 제외한다.
  Future<void> configureNotificationHandler() async {
    if (platform == null) return;
    try {
      if (!await _gateway.initialize()) return;
      await _gateway.setForegroundPresentationOptions();
    } catch (e) {
      debugPrint('[push] 알림 핸들러 설정 실패(무시): $e');
    }
  }

  /// 권한을 요청하고, 허용되면 FCM registration token을 반환한다.
  /// 미지원 플랫폼/Firebase 미설정/권한 거부/토큰 발급 실패는 모두 null.
  Future<String?> registerForPushNotificationsAsync() async {
    if (platform == null) return null;
    try {
      if (!await _gateway.initialize()) return null;

      final status = await _gateway.requestPermission();
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        return null;
      }

      final token = await _gateway.getToken();
      return (token == null || token.isEmpty) ? null : token;
    } catch (e) {
      debugPrint('[push] 푸시 토큰 발급 실패(무시): $e');
      return null;
    }
  }
}

/// 로그인 완료 시 토큰 발급 → devices 등록. RN `AuthContext.refreshMember`의 try/catch 블록에 대응.
/// 실패는 전부 삼킨다(soft-fail) — 푸시 등록이 로그인/앱 사용을 막으면 안 된다.
class PushDeviceRegistrar {
  PushDeviceRegistrar({required this.push, required this.devices});

  final PushNotificationsService push;
  final DevicesService devices;

  Future<void> register() async {
    try {
      final token = await push.registerForPushNotificationsAsync();
      final platform = push.platform;
      if (token != null && platform != null) {
        await devices.registerDevice(token, platform);
      }
    } catch (e) {
      debugPrint('[push] devices 등록 실패(무시): $e');
    }
  }
}
