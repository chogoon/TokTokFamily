import 'package:family_toktok/screens/kid_scan_qr_screen.dart';
import 'package:family_toktok/screens/parent_account_screen.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('"아이인가요? QR로 로그인하기" 링크로 QR 스캔 화면을 연다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const ParentAccountScreen(),
    ));

    final link = find.text('🙂 아이인가요? QR로 로그인하기');
    expect(link, findsOneWidget);
    await tester.ensureVisible(link);

    // 실제 permission_handler 채널은 위젯 테스트에서 응답하지 않으므로 push까지만 확인한다.
    await tester.tap(link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(KidScanQrScreen), findsOneWidget);
  });
}
