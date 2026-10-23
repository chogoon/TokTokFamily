import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/screens/home_screen.dart';
import 'package:family_toktok/models/praise.dart';
import 'package:family_toktok/models/mood.dart';
import 'package:family_toktok/services/members_service.dart';
import 'package:family_toktok/services/moods_service.dart';
import 'package:family_toktok/services/praises_service.dart';
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

class _Praises implements PraisesService {
  int boardFetches = 0;
  @override
  Future<PraiseBoard?> fetchActiveBoard(String kidMemberId) async {
    boardFetches++;
    return null;
  }

  @override
  Future<List<PraiseEntry>> fetchPraises(String boardId) async => const [];
  @override
  Future<void> addPraise(String boardId, String text) async {}
  @override
  Future<void> addPraiseToAllKids(List<String> kidMemberIds, String text) async {}
  @override
  Future<void> claimReward(PraiseBoard board) async {}
  @override
  Future<void> saveGoal(String boardId, String goalText) async {}
}

class _Moods implements MoodsService {
  int todayFetches = 0;
  @override
  Future<List<FamilyTodayMood>> fetchTodayMoods() async {
    todayFetches++;
    return const [];
  }

  @override
  Future<List<MoodEntry>> fetchMyWeeklyMoods(String memberId) async =>
      const [];
  @override
  Future<bool> saveMood(String emoji, {String? note}) async => false;
}

void main() {
  testWidgets('대화/기분/칭찬/가족 4개 탭, 기본은 대화 탭, 탭 전환', (tester) async {
    final backend = FakeKidAuthBackend()..signedIn = true;
    final auth = AuthController(backend);
    await auth.initialize();
    final rooms = FakeRoomsService();
    final praises = _Praises();
    final moods = _Moods();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<RoomsService>.value(value: rooms),
        Provider<MembersService>.value(value: _Members()),
        Provider<PraisesService>.value(value: praises),
        Provider<MoodsService>.value(value: moods),
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

    // 기분 탭: 들어올 때마다 오늘/주간 기분을 새로 읽는다 (RN useFocusEffect 대응)
    final moodBefore = moods.todayFetches;
    await tester.tap(find.text('기분'));
    await tester.pumpAndSettle();
    expect(find.text('🌈 기분'), findsOneWidget);
    expect(moods.todayFetches, moodBefore + 1);

    // 칭찬 탭: 들어올 때마다 칭찬판을 새로 읽는다 (RN useFocusEffect 대응)
    final praiseBefore = praises.boardFetches;
    await tester.tap(find.text('칭찬'));
    await tester.pumpAndSettle();
    expect(find.text('⭐ 칭찬판'), findsOneWidget);
    expect(praises.boardFetches, praiseBefore + 1);

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
