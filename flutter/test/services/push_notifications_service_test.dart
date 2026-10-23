import 'package:family_toktok/services/devices_service.dart';
import 'package:family_toktok/services/push_notifications_service.dart';
import 'package:family_toktok/utils/push_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements PushMessagingGateway {
  bool available = true;
  bool throwOnInit = false;
  AuthorizationStatus status = AuthorizationStatus.authorized;
  Object? permissionError;
  String? token = 'fcm-token';
  Object? tokenError;
  Object? foregroundError;

  int initCalls = 0;
  int permissionCalls = 0;
  int tokenCalls = 0;
  int foregroundCalls = 0;

  @override
  Future<bool> initialize() async {
    initCalls++;
    if (throwOnInit) throw Exception('no google-services.json');
    return available;
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    permissionCalls++;
    if (permissionError != null) throw permissionError!;
    return status;
  }

  @override
  Future<String?> getToken() async {
    tokenCalls++;
    if (tokenError != null) throw tokenError!;
    return token;
  }

  @override
  Future<void> setForegroundPresentationOptions() async {
    foregroundCalls++;
    if (foregroundError != null) throw foregroundError!;
  }
}

class FakeDevicesService implements DevicesService {
  final registered = <(String, DevicePlatform)>[];
  Object? error;

  @override
  Future<void> registerDevice(String pushToken, DevicePlatform platform) async {
    if (error != null) throw error!;
    registered.add((pushToken, platform));
  }

  @override
  Future<void> unregisterDevice(String pushToken) async {}
}

void main() {
  late FakeGateway gateway;

  PushNotificationsService service({String? osName = 'android'}) =>
      PushNotificationsService(gateway, osName: osName);

  setUp(() => gateway = FakeGateway());

  group('registerForPushNotificationsAsync', () {
    test('권한이 허용되면 FCM 토큰을 반환한다', () async {
      expect(await service().registerForPushNotificationsAsync(), 'fcm-token');
      expect(gateway.permissionCalls, 1);
    });

    test('임시 허용(provisional, iOS)도 토큰을 반환한다', () async {
      gateway.status = AuthorizationStatus.provisional;
      expect(await service(osName: 'ios').registerForPushNotificationsAsync(),
          'fcm-token');
    });

    test('권한 거부면 null이고 토큰을 요청하지 않는다', () async {
      gateway.status = AuthorizationStatus.denied;
      expect(await service().registerForPushNotificationsAsync(), isNull);
      expect(gateway.tokenCalls, 0);
    });

    test('권한 미결정이면 null', () async {
      gateway.status = AuthorizationStatus.notDetermined;
      expect(await service().registerForPushNotificationsAsync(), isNull);
    });

    test('Firebase 설정 파일이 없어 초기화가 불가하면 null (권한도 묻지 않음)', () async {
      gateway.available = false;
      expect(await service().registerForPushNotificationsAsync(), isNull);
      expect(gateway.permissionCalls, 0);
    });

    test('Firebase 초기화가 throw해도 null (throw하지 않음)', () async {
      gateway.throwOnInit = true;
      expect(await service().registerForPushNotificationsAsync(), isNull);
    });

    test('권한 요청이 throw해도 null', () async {
      gateway.permissionError = Exception('boom');
      expect(await service().registerForPushNotificationsAsync(), isNull);
    });

    test('토큰 발급이 throw해도 null', () async {
      gateway.tokenError = Exception('SERVICE_NOT_AVAILABLE');
      expect(await service().registerForPushNotificationsAsync(), isNull);
    });

    test('토큰이 빈 문자열이면 null', () async {
      gateway.token = '';
      expect(await service().registerForPushNotificationsAsync(), isNull);
    });

    test('지원하지 않는 플랫폼(web/desktop)이면 Firebase를 건드리지 않고 null', () async {
      for (final os in [null, 'macos', 'linux']) {
        gateway = FakeGateway();
        expect(await service(osName: os).registerForPushNotificationsAsync(),
            isNull,
            reason: '$os');
        expect(gateway.initCalls, 0);
      }
    });
  });

  group('configureNotificationHandler', () {
    test('포그라운드 표시 옵션을 설정한다', () async {
      await service(osName: 'ios').configureNotificationHandler();
      expect(gateway.foregroundCalls, 1);
    });

    test('Firebase를 쓸 수 없으면 아무것도 하지 않는다', () async {
      gateway.available = false;
      await service().configureNotificationHandler();
      expect(gateway.foregroundCalls, 0);
    });

    test('실패해도 throw하지 않는다', () async {
      gateway.foregroundError = Exception('boom');
      await service().configureNotificationHandler();
      gateway.throwOnInit = true;
      await service().configureNotificationHandler();
    });
  });

  group('PushDeviceRegistrar', () {
    late FakeDevicesService devices;
    setUp(() => devices = FakeDevicesService());

    test('토큰을 받으면 해당 플랫폼으로 devices에 등록한다', () async {
      await PushDeviceRegistrar(push: service(osName: 'ios'), devices: devices)
          .register();
      expect(devices.registered, [('fcm-token', DevicePlatform.ios)]);
    });

    test('토큰이 없으면(권한 거부 등) 등록하지 않는다', () async {
      gateway.status = AuthorizationStatus.denied;
      await PushDeviceRegistrar(push: service(), devices: devices).register();
      expect(devices.registered, isEmpty);
    });

    test('devices 등록 실패는 삼킨다 (throw하지 않음)', () async {
      devices.error = Exception('RLS');
      await PushDeviceRegistrar(push: service(), devices: devices).register();
    });
  });
}
