import 'dart:convert';

import 'package:family_toktok/screens/qr_issue_screen.dart';
import 'package:family_toktok/services/api_client.dart';
import 'package:family_toktok/services/qr_auth_service.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _token = 'super-secret-qr-token';

void main() {
  late int issues;
  late DateTime clock;

  Widget app() {
    issues = 0;
    final api = ApiClient(
      baseUrl: 'http://localhost:4000',
      httpClient: MockClient((r) async {
        issues++;
        final expiresAt = clock.add(const Duration(minutes: 2));
        return http.Response(
          jsonEncode({
            'token': _token,
            'shortCode': issues == 1 ? '482913' : '135790',
            'expiresAt': expiresAt.toUtc().toIso8601String(),
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
      accessTokenProvider: () async => 'jwt',
    );
    return Provider<QrAuthService>.value(
      value: QrAuthService(api),
      child: MaterialApp(
        theme: buildAppTheme(),
        home: QrIssueScreen(
          kidMemberId: 'k1',
          kidName: '하린',
          now: () => clock,
        ),
      ),
    );
  }

  setUp(() => clock = DateTime.utc(2026, 10, 22, 12));

  testWidgets('QR 이미지와 "482 913" 형식 코드, 남은 시간을 보여주고 토큰은 텍스트로 노출하지 않는다',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('또는 이 번호를 아이에게 알려주세요'), findsOneWidget);
    expect(find.text('남은 시간 02:00'), findsOneWidget);
    expect(find.textContaining(_token), findsNothing);
    expect(find.bySemanticsLabel(RegExp(_token)), findsNothing);
  });

  testWidgets('1초마다 카운트다운하고 만료되면 새로 만들기로 재발급한다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();

    clock = clock.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('남은 시간 00:59'), findsOneWidget);

    clock = clock.add(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('482 913'), findsNothing);
    expect(find.text('새로 만들기'), findsOneWidget);

    await tester.tap(find.text('새로 만들기'));
    await tester.pump();
    await tester.pump();

    expect(issues, 2);
    expect(find.text('135 790'), findsOneWidget);
    expect(find.text('남은 시간 02:00'), findsOneWidget);
  });
}
