import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/screens/home_screen.dart';
import 'package:family_toktok/services/members_service.dart';
import 'package:family_toktok/services/rooms_service.dart';
import 'package:family_toktok/state/auth_controller.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'kid_login_test_helpers.dart';
import 'rooms_test_helpers.dart';

class _Members implements MembersService {
  @override
  Future<List<Member>> fetchFamilyMembers() async => const [kidMember];
}

void main() {
  testWidgets('대화/기분/칭찬/가족 4개 탭, 기본은 대화 탭, 탭 전환', (tester) async {
    final backend = FakeKidAuthBackend()..signedIn = true;
    final auth = AuthController(backend);
    await auth.initialize();
    final rooms = FakeRoomsService();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<RoomsService>.value(value: rooms),
        Provider<MembersService>.value(value: _Members()),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
    ));
    await tester.pumpAndSettle();

    for (final label in ['대화', '기분', '칭찬', '가족']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('로그아웃'), findsOneWidget);
    // 대화 탭이 기본
    expect(find.text('아직 대화방이 없어요'), findsOneWidget);

    await tester.tap(find.text('기분'));
    await tester.pumpAndSettle();
    expect(find.text('다음 단계에서 구현됩니다'), findsOneWidget);

    await tester.tap(find.text('가족'));
    await tester.pumpAndSettle();
    expect(find.text('👪 우리 가족'), findsOneWidget);

    // 대화 탭으로 돌아오면 목록을 새로 읽는다 (RN useFocusEffect 대응)
    final before = rooms.fetchRoomsCalls;
    await tester.tap(find.text('대화'));
    await tester.pumpAndSettle();
    expect(rooms.fetchRoomsCalls, before + 1);
  });
}
