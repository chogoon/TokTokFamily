import 'package:family_toktok/screens/kid_enter_code_screen.dart';
import 'package:family_toktok/screens/kid_scan_qr_screen.dart';
import 'package:family_toktok/state/auth_controller.dart';
import 'package:family_toktok/utils/camera_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kid_login_test_helpers.dart';

class FakeCameraPermission implements CameraPermissionGateway {
  FakeCameraPermission({
    this.current = CameraPermissionState.granted,
    this.afterRequest,
  });

  CameraPermissionState current;
  CameraPermissionState? afterRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<CameraPermissionState> check() async => current;

  @override
  Future<CameraPermissionState> request() async {
    requests++;
    current = afterRequest ?? current;
    return current;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

const _secret = 'super-secret-qr-token';

/// 실제 카메라 대신 버튼으로 "스캔됨"을 흉내 낸다.
Widget _fakeScanner(BuildContext context, ValueChanged<String> onCode) {
  return Center(
    child: TextButton(
      key: const Key('fake-scan'),
      onPressed: () => onCode(_secret),
      child: const Text('스캔 시뮬레이션'),
    ),
  );
}

void main() {
  Future<KidLoginHarness> pumpScreen(
    WidgetTester tester, {
    FakeCameraPermission? permission,
    int status = 200,
    Object? body,
  }) async {
    final h = KidLoginHarness(status: status, body: body);
    await tester.pumpWidget(await h.build(KidScanQrScreen(
      permission: permission ?? FakeCameraPermission(),
      scannerBuilder: _fakeScanner,
      codeScreenBuilder: (_) => const KidEnterCodeScreen(),
    )));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('권한이 있으면 스캐너를 띄우고, 스캔 성공 시 redeem 후 로그인한다',
      (tester) async {
    final h = await pumpScreen(tester);

    expect(find.byKey(const Key('fake-scan')), findsOneWidget);
    expect(find.text('부모님 화면에 보이는 QR을 카메라에 비춰주세요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('fake-scan')));
    await tester.pumpAndSettle();

    expect(h.requests.single.url.path, '/auth/qr/redeem');
    expect(h.lastBody, {'token': _secret});
    expect(h.auth.status, AuthStatus.ready);
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('같은 QR이 연속으로 감지돼도 한 번만 처리한다', (tester) async {
    late ValueChanged<String> capture;
    final h = KidLoginHarness();
    await tester.pumpWidget(await h.build(KidScanQrScreen(
      permission: FakeCameraPermission(),
      scannerBuilder: (_, onCode) {
        capture = onCode;
        return const SizedBox();
      },
    )));
    await tester.pumpAndSettle();

    capture(_secret);
    capture(_secret);
    capture(_secret);
    await tester.pumpAndSettle();

    expect(h.requests, hasLength(1));
  });

  final cases = {
    404: 'QR을 찾을 수 없어요',
    409: '이미 사용한 QR이에요',
    410: 'QR 시간이 지났어요',
  };
  for (final entry in cases.entries) {
    testWidgets('${entry.key}면 "${entry.value}" + 다시 스캔하기로 스캐너 복귀',
        (tester) async {
      final h =
          await pumpScreen(tester, status: entry.key, body: {'error': 'x'});

      await tester.tap(find.byKey(const Key('fake-scan')));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(find.byKey(const Key('fake-scan')), findsNothing);
      expect(h.appliedSessions, isEmpty);

      await tester.tap(find.text('다시 스캔하기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-scan')), findsOneWidget);

      await tester.tap(find.byKey(const Key('fake-scan')));
      await tester.pumpAndSettle();
      expect(h.requests, hasLength(2));
    });
  }

  testWidgets('QR 토큰 문자열은 화면 텍스트/semantics에 나타나지 않는다', (tester) async {
    await pumpScreen(tester, status: 404, body: {'error': 'token not found'});

    await tester.tap(find.byKey(const Key('fake-scan')));
    await tester.pumpAndSettle();

    expect(find.textContaining(_secret), findsNothing);
    expect(find.bySemanticsLabel(RegExp(_secret)), findsNothing);
  });

  testWidgets('can-ask면 카메라 켜기 → 권한 요청 후 스캐너', (tester) async {
    final permission = FakeCameraPermission(
      current: CameraPermissionState.canAsk,
      afterRequest: CameraPermissionState.granted,
    );
    await pumpScreen(tester, permission: permission);

    expect(find.byKey(const Key('fake-scan')), findsNothing);
    expect(find.text('카메라를 보여주세요'), findsOneWidget);

    await tester.tap(find.text('카메라 켜기'));
    await tester.pumpAndSettle();

    expect(permission.requests, 1);
    expect(find.byKey(const Key('fake-scan')), findsOneWidget);
  });

  testWidgets('요청했는데 영구 거부되면 blocked 안내로 바뀐다', (tester) async {
    final permission = FakeCameraPermission(
      current: CameraPermissionState.canAsk,
      afterRequest: CameraPermissionState.blocked,
    );
    await pumpScreen(tester, permission: permission);

    await tester.tap(find.text('카메라 켜기'));
    await tester.pumpAndSettle();

    expect(find.text('카메라 권한이 꺼져 있어요'), findsOneWidget);
  });

  testWidgets('blocked면 설정 열기 버튼, 설정에서 돌아오면(resumed) 권한을 다시 확인한다',
      (tester) async {
    final permission =
        FakeCameraPermission(current: CameraPermissionState.blocked);
    await pumpScreen(tester, permission: permission);

    expect(find.text('카메라 권한이 꺼져 있어요'), findsOneWidget);
    await tester.tap(find.text('설정에서 카메라 켜기'));
    await tester.pumpAndSettle();
    expect(permission.settingsOpened, 1);
    expect(permission.requests, 0);

    permission.current = CameraPermissionState.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-scan')), findsOneWidget);
  });

  testWidgets('권한이 없어도 "번호로 입력하기"로 코드 입력 화면에 갈 수 있다', (tester) async {
    await pumpScreen(tester,
        permission:
            FakeCameraPermission(current: CameraPermissionState.blocked));

    await tester.tap(find.text('QR이 안 보이나요? 번호로 입력하기'));
    await tester.pumpAndSettle();

    expect(find.byType(KidEnterCodeScreen), findsOneWidget);
    expect(find.byType(KidScanQrScreen), findsNothing);
  });
}
