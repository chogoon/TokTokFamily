import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/models/mood.dart';
import 'package:family_toktok/screens/mood_screen.dart';
import 'package:family_toktok/services/members_service.dart';
import 'package:family_toktok/services/moods_service.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:family_toktok/utils/moods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _mom =
    Member(id: 'p1', familyId: 'f1', role: MemberRole.parent, name: '엄마');
const _harin = Member(
    id: 'k1', familyId: 'f1', role: MemberRole.kid, name: '하린', avatar: '🐰');
const _doyun = Member(
    id: 'k2', familyId: 'f1', role: MemberRole.kid, name: '도윤', avatar: '🐻');

class _Members implements MembersService {
  @override
  Future<List<Member>> fetchFamilyMembers() async =>
      const [_mom, _harin, _doyun];
}

class _FakeMoods implements MoodsService {
  List<FamilyTodayMood> today = const [];
  Map<String, List<MoodEntry>> weekly = {};
  bool notifyResult = false;
  Object? saveError;

  final saved = <(String, String?)>[];
  final weeklyRequests = <String>[];
  int todayFetches = 0;

  @override
  Future<List<FamilyTodayMood>> fetchTodayMoods() async {
    todayFetches++;
    return today;
  }

  @override
  Future<List<MoodEntry>> fetchMyWeeklyMoods(String memberId) async {
    weeklyRequests.add(memberId);
    return weekly[memberId] ?? const [];
  }

  @override
  Future<bool> saveMood(String emoji, {String? note}) async {
    if (saveError != null) throw saveError!;
    saved.add((emoji, note));
    return notifyResult;
  }
}

void main() {
  late _FakeMoods fake;
  final todayKey = formatMoodDate(DateTime.now());

  setUp(() => fake = _FakeMoods());

  Future<void> pump(WidgetTester tester, Member me) async {
    // 세 카드를 모두 한 화면에 그리도록 세로로 긴 화면을 쓴다 (ListView는 화면 밖을 지연 생성).
    tester.view.physicalSize = const Size(440, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<MembersService>.value(value: _Members()),
        Provider<MoodsService>.value(value: fake),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: MoodScreen(me: me)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('이모지 5개와 라벨, 아이용 안내 문구', (tester) async {
    await pump(tester, _harin);
    expect(find.text('🌈 기분'), findsOneWidget);
    expect(find.text('하린아, 오늘 기분은 어때?'), findsOneWidget);
    for (final m in moods) {
      expect(find.text(m.label), findsOneWidget);
    }
    expect(find.textContaining('이유는 엄마, 아빠만 볼 수 있어요'), findsOneWidget);
  });

  testWidgets('보호자용 제목과 안내 문구', (tester) async {
    await pump(tester, _mom);
    expect(find.text('엄마의 오늘 기분'), findsOneWidget);
    expect(find.textContaining('부모님끼리만 보여요'), findsOneWidget);
    expect(find.text('아이들의 일주일 기분'), findsOneWidget);
  });

  testWidgets('기분을 안 고르고 누르면 고르라고 안내하고 저장하지 않는다', (tester) async {
    await pump(tester, _harin);
    await tester.tap(find.text('기분 알려주기'));
    await tester.pump();
    expect(find.text('기분을 하나 골라줘!'), findsOneWidget);
    expect(fake.saved, isEmpty);
  });

  testWidgets('아이가 슬픔을 고르고 이유를 적으면 저장 후 보호자 알림 토스트', (tester) async {
    fake.notifyResult = true;
    await pump(tester, _harin);

    await tester.tap(find.byKey(const Key('mood-😢')));
    await tester.enterText(find.byType(TextField), '  넘어졌어 ');
    await tester.tap(find.text('기분 알려주기'));
    await tester.pump();
    await tester.pump();

    expect(fake.saved, [('😢', '넘어졌어')]);
    expect(find.text('엄마 아빠가 마음을 알게 됐어요 🤗'), findsOneWidget);
    // 저장 후 다시 읽는다
    expect(fake.todayFetches, 2);
  });

  testWidgets('아이가 좋은 기분이면 일반 토스트, 이유 없으면 note null', (tester) async {
    await pump(tester, _harin);
    await tester.tap(find.byKey(const Key('mood-😆')));
    await tester.tap(find.text('기분 알려주기'));
    await tester.pump();
    await tester.pump();
    expect(fake.saved, [('😆', null)]);
    expect(find.text('기분을 알려줬어요!'), findsOneWidget);
  });

  testWidgets('보호자가 슬픔을 골라도 알림 토스트가 아니라 일반 토스트', (tester) async {
    await pump(tester, _mom);
    await tester.tap(find.byKey(const Key('mood-😢')));
    await tester.tap(find.text('기분 알려주기'));
    await tester.pump();
    await tester.pump();
    expect(find.text('기분을 알려줬어요!'), findsOneWidget);
  });

  testWidgets('저장 실패 시 안내', (tester) async {
    fake.saveError = Exception('x');
    await pump(tester, _harin);
    await tester.tap(find.byKey(const Key('mood-🙂')));
    await tester.tap(find.text('기분 알려주기'));
    await tester.pump();
    await tester.pump();
    expect(find.text('기분을 저장하지 못했어요'), findsOneWidget);
  });

  testWidgets('이유 입력은 최대 200자', (tester) async {
    await pump(tester, _harin);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 200);
  });

  testWidgets('가족 기분판: 아이는 형제의 이유를 보지 못한다 (데이터에 있어도 2차 차단)', (tester) async {
    // RLS가 실수로 형제 note를 돌려줬다고 가정해도 화면이 canSeeNote로 가려야 한다.
    fake.today = [
      FamilyTodayMood(
          memberId: 'k1', date: todayKey, emoji: '🙂', note: '내 이유'),
      FamilyTodayMood(
          memberId: 'k2', date: todayKey, emoji: '😠', note: '형제 비밀'),
      FamilyTodayMood(
          memberId: 'p1', date: todayKey, emoji: '😐', note: '엄마 이유'),
    ];
    await pump(tester, _harin);

    expect(find.text('"내 이유"'), findsOneWidget);
    expect(find.textContaining('형제 비밀'), findsNothing);
    expect(find.textContaining('엄마 이유'), findsNothing);
    // 이모지는 전체 공개
    expect(find.byKey(const Key('today-k2')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('today-k2')), matching: find.text('😠')),
        findsOneWidget);
    // 내 오늘 기분이 미리 선택돼 있다
    expect(find.byKey(const Key('mood-🙂-selected')), findsOneWidget);
  });

  testWidgets('가족 기분판: 보호자는 모든 이유를 본다, 기록 없는 사람은 ❔', (tester) async {
    fake.today = [
      FamilyTodayMood(memberId: 'k2', date: todayKey, emoji: '😠', note: '장난감'),
    ];
    await pump(tester, _mom);
    expect(find.text('"장난감"'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('today-k1')), matching: find.text('❔')),
        findsOneWidget);
  });

  testWidgets('주간 기록: 아이는 본인 것만 조회한다', (tester) async {
    fake.weekly = {
      'k1': [
        MoodEntry(id: 'm1', memberId: 'k1', date: todayKey, emoji: '😆'),
      ],
    };
    await pump(tester, _harin);
    expect(fake.weeklyRequests, ['k1']);
    expect(find.text('나의 이번 주 기분'), findsOneWidget);
    expect(find.text('오늘'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('week-k1-today')),
            matching: find.text('😆')),
        findsOneWidget);
    // 형제의 주간 기록 블록은 없다
    expect(find.byKey(const Key('week-k2')), findsNothing);
  });

  testWidgets('주간 기록: 보호자는 아이별로 본다', (tester) async {
    await pump(tester, _mom);
    expect(fake.weeklyRequests, unorderedEquals(['k1', 'k2']));
    expect(find.byKey(const Key('week-k1')), findsOneWidget);
    expect(find.byKey(const Key('week-k2')), findsOneWidget);
    expect(find.text('🐰 하린'), findsOneWidget);
    expect(find.text('오늘'), findsNWidgets(2));
  });
}
