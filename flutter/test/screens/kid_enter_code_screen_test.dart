import 'package:family_toktok/screens/kid_enter_code_screen.dart';
import 'package:family_toktok/screens/kid_scan_qr_screen.dart';
import 'package:family_toktok/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kid_login_test_helpers.dart';
import 'kid_scan_qr_screen_test.dart' show FakeCameraPermission;

void main() {
  testWidgets('숫자만 받아 6자리가 채워지면 자동으로 /auth/code/redeem을 호출하고 로그인한다',
      (tester) async {
    final h = KidLoginHarness();
    await tester.pumpWidget(await h.build(const KidEnterCodeScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '48a2');
    await tester.pump();
    expect(h.requests, isEmpty);

    await tester.enterText(find.byType(TextField), '482 913');
    await tester.pumpAndSettle();

    expect(h.requests, hasLength(1));
    expect(h.requests.single.url.path, '/auth/code/redeem');
    expect(h.lastBody, {'shortCode': '482913'});
    expect(h.appliedSessions, ['access-abc']);
    expect(h.auth.status, AuthStatus.ready);
    // 로그인 후 루트(AuthGate)로 돌아간다
    expect(find.text('ROOT'), findsOneWidget);
  });

  final cases = {
    404: '번호를 찾을 수 없어요',
    409: '이미 사용한 번호예요',
    410: '번호 시간이 지났어요',
    429: '너무 많이 시도했어요, 잠시 후 다시 해주세요',
  };
  for (final entry in cases.entries) {
    testWidgets('${entry.key}면 "${entry.value}" 안내 + 다시 입력하기', (tester) async {
      final h = KidLoginHarness(status: entry.key, body: {'error': 'x'});
      await tester.pumpWidget(await h.build(const KidEnterCodeScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '482913');
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(h.appliedSessions, isEmpty);

      await tester.tap(find.text('다시 입력하기'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);

      // 다시 입력하면 다시 제출된다 (중복 제출 플래그가 풀렸는지)
      h.status = 200;
      h.body = {'accessToken': 'a', 'refreshToken': 'r', 'authUserId': 'k'};
      await tester.enterText(find.byType(TextField), '135790');
      await tester.pumpAndSettle();
      expect(h.requests, hasLength(2));
    });
  }

  testWidgets('"QR로 스캔하기"로 QR 스캔 화면으로 바꾼다', (tester) async {
    final h = KidLoginHarness();
    await tester.pumpWidget(await h.build(KidEnterCodeScreen(
      scanScreenBuilder: (_) => KidScanQrScreen(
        permission: FakeCameraPermission(),
        scannerBuilder: (_, __) => const SizedBox(),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('QR로 스캔하기'));
    await tester.pumpAndSettle();

    expect(find.byType(KidScanQrScreen), findsOneWidget);
    expect(find.byType(KidEnterCodeScreen), findsNothing);
  });
}
