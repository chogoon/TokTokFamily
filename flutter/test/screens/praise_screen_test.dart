import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/models/praise.dart';
import 'package:family_toktok/screens/praise_screen.dart';
import 'package:family_toktok/services/members_service.dart';
import 'package:family_toktok/services/praises_service.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _mom =
    Member(id: 'p1', familyId: 'f1', role: MemberRole.parent, name: '엄마');
const _harin = Member(
    id: 'k1',
    familyId: 'f1',
    role: MemberRole.kid,
    name: '하린',
    avatar: '🐰',
    color: '#FFB547');
const _jun = Member(
    id: 'k2', familyId: 'f1', role: MemberRole.kid, name: '준', avatar: '🦖');

class _Members implements MembersService {
  _Members(this.members);
  List<Member> members;
  @override
  Future<List<Member>> fetchFamilyMembers() async => List.of(members);
}

PraiseBoard _board(String id, String kid, {String goal = '보드게임 사기'}) =>
    PraiseBoard(
      id: id,
      kidMemberId: kid,
      familyId: 'f1',
      goalText: goal,
      targetCount: 10,
      status: PraiseBoardStatus.active,
    );

List<PraiseEntry> _entries(String boardId, int n) => [
      for (var i = 0; i < n; i++)
        PraiseEntry(
          id: '$boardId-$i',
          boardId: boardId,
          giverId: 'p1',
          giverName: '엄마',
          text: '칭찬$i',
          createdAt: DateTime.utc(2026, 10, 20, i),
        ),
    ];

class _FakePraises implements PraisesService {
  Map<String, PraiseBoard> boardsByKid = {};
  Map<String, List<PraiseEntry>> praisesByBoard = {};
  Object? fetchError;
  Object? addError;

  final fetchedKids = <String>[];
  final added = <(String, String)>[];
  final addedToAll = <(List<String>, String)>[];
  final claimed = <PraiseBoard>[];
  final savedGoals = <(String, String)>[];

  @override
  Future<PraiseBoard?> fetchActiveBoard(String kidMemberId) async {
    fetchedKids.add(kidMemberId);
    if (fetchError != null) throw fetchError!;
    return boardsByKid[kidMemberId];
  }

  @override
  Future<List<PraiseEntry>> fetchPraises(String boardId) async =>
      List.of(praisesByBoard[boardId] ?? const []);

  @override
  Future<void> addPraise(String boardId, String text) async {
    if (addError != null) throw addError!;
    added.add((boardId, text));
    final list = praisesByBoard[boardId] ?? [];
    praisesByBoard[boardId] = [
      PraiseEntry(
        id: 'new-${list.length}',
        boardId: boardId,
        giverId: 'p1',
        giverName: '엄마',
        text: text,
        createdAt: DateTime.utc(2026, 10, 22),
      ),
      ...list,
    ];
  }

  @override
  Future<void> addPraiseToAllKids(
      List<String> kidMemberIds, String text) async {
    addedToAll.add((kidMemberIds, text));
  }

  @override
  Future<void> claimReward(PraiseBoard board) async {
    claimed.add(board);
    boardsByKid[board.kidMemberId] =
        _board('${board.id}-next', board.kidMemberId, goal: board.goalText);
  }

  @override
  Future<void> saveGoal(String boardId, String goalText) async {
    savedGoals.add((boardId, goalText));
    for (final e in boardsByKid.entries.toList()) {
      if (e.value.id == boardId) {
        boardsByKid[e.key] = _board(boardId, e.key, goal: goalText);
      }
    }
  }
}

void main() {
  late _FakePraises praises;
  late _Members members;

  setUp(() {
    praises = _FakePraises()
      ..boardsByKid = {'k1': _board('b1', 'k1'), 'k2': _board('b2', 'k2')}
      ..praisesByBoard = {'b1': _entries('b1', 3), 'b2': _entries('b2', 7)};
    members = _Members(const [_mom, _harin, _jun]);
  });

  Future<void> pump(WidgetTester tester, Member me) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<MembersService>.value(value: members),
        Provider<PraisesService>.value(value: praises),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: PraiseScreen(me: me)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  group('보호자', () {
    testWidgets('첫 아이 칭찬판: 제목/진행도/10슬롯(3개 채움)/입력/기록', (tester) async {
      await pump(tester, _mom);

      expect(find.text('⭐ 칭찬판'), findsOneWidget);
      expect(find.text('⭐ 하린의 칭찬 스티커'), findsOneWidget);
      expect(find.text('🎯 10개 모으면: 보드게임 사기 (3/10)'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('praise-slot-filled')), findsNWidgets(3));
      expect(find.byKey(const ValueKey('praise-slot-empty')), findsNWidgets(7));
      expect(find.text('하린에게 스티커 붙여주기'), findsOneWidget);
      expect(find.text('👫 아이들 모두에게 붙여주기 (함께 한 일)'), findsOneWidget);
      // 목표 미달성이면 보상 버튼 없음
      expect(find.text('🎁 약속 지켰어요! 새 판 시작하기'), findsNothing);
      expect(find.text('보기만 가능'), findsNothing);
      await scrollTo(tester, find.text('칭찬 기록'));
      expect(find.text('🎯 목표 바꾸기'), findsOneWidget);
      expect(praises.fetchedKids, ['k1']);
    });

    testWidgets('CRITICAL: 아이 선택 pill은 아바타+이름만, 칭찬 개수/진행률 숫자 없음',
        (tester) async {
      await pump(tester, _mom);

      final pills = find
          .byKey(const ValueKey('kid-pill-k1'))
          .evaluate()
          .toList()
        ..addAll(find.byKey(const ValueKey('kid-pill-k2')).evaluate());
      expect(pills, hasLength(2));
      for (final key in ['kid-pill-k1', 'kid-pill-k2']) {
        final texts = find
            .descendant(
                of: find.byKey(ValueKey(key)), matching: find.byType(Text))
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .toList();
        expect(texts.join(), isNot(matches(RegExp(r'\d'))),
            reason: '형제 비교 금지: pill에 숫자 표시 안 함');
      }
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('kid-pill-k1')),
              matching: find.text('🐰 하린')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('kid-pill-k2')),
              matching: find.text('🦖 준')),
          findsOneWidget);
      // 화면 어디에도 다른 아이(준, 7개)의 진행도가 함께 보이지 않는다
      expect(find.textContaining('7/10'), findsNothing);
    });

    testWidgets('pill을 누르면 그 아이 칭찬판으로 바뀐다', (tester) async {
      await pump(tester, _mom);
      await tester.tap(find.byKey(const ValueKey('kid-pill-k2')));
      await tester.pumpAndSettle();
      expect(find.text('⭐ 준의 칭찬 스티커'), findsOneWidget);
      expect(find.text('🎯 10개 모으면: 보드게임 사기 (7/10)'), findsOneWidget);
      expect(find.textContaining('3/10'), findsNothing);
      expect(praises.fetchedKids, ['k1', 'k2']);
    });

    testWidgets('칭찬 추가: addPraise 호출 + 입력 비움 + 다시 읽기 + 안내', (tester) async {
      await pump(tester, _mom);
      await tester.enterText(
          find.byKey(const ValueKey('praise-input')), '  스스로 숙제했어요 ');
      await tester.tap(find.text('하린에게 스티커 붙여주기'));
      await tester.pumpAndSettle();

      expect(praises.added, [('b1', '스스로 숙제했어요')]);
      expect(find.text('⭐ 스티커를 붙였어요'), findsOneWidget);
      expect(find.text('🎯 10개 모으면: 보드게임 사기 (4/10)'), findsOneWidget);
      final field =
          tester.widget<TextField>(find.byKey(const ValueKey('praise-input')));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('빈 칭찬은 보내지 않는다', (tester) async {
      await pump(tester, _mom);
      await tester.enterText(find.byKey(const ValueKey('praise-input')), '   ');
      await tester.tap(find.text('하린에게 스티커 붙여주기'));
      await tester.pumpAndSettle();
      expect(praises.added, isEmpty);
    });

    testWidgets('10번째 칭찬이면 목표 달성 안내 + 보상 버튼 노출', (tester) async {
      praises.praisesByBoard['b1'] = _entries('b1', 9);
      await pump(tester, _mom);
      expect(find.text('🎁 약속 지켰어요! 새 판 시작하기'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('praise-input')), '정리');
      await tester.tap(find.text('하린에게 스티커 붙여주기'));
      await tester.pumpAndSettle();

      expect(find.text('🎉 목표 달성! 약속을 지켜주세요'), findsOneWidget);
      expect(find.text('🎁 약속 지켰어요! 새 판 시작하기'), findsOneWidget);
    });

    testWidgets('칭찬 추가 실패면 에러 안내', (tester) async {
      praises.addError = Exception('x');
      await pump(tester, _mom);
      await tester.enterText(find.byKey(const ValueKey('praise-input')), '정리');
      await tester.tap(find.text('하린에게 스티커 붙여주기'));
      await tester.pumpAndSettle();
      expect(find.text('칭찬을 추가하지 못했어요'), findsOneWidget);
    });

    testWidgets('모두에게 칭찬: 모든 아이 id로 addPraiseToAllKids', (tester) async {
      await pump(tester, _mom);
      await tester.enterText(
          find.byKey(const ValueKey('praise-input')), '같이 청소했어요');
      await tester.tap(find.text('👫 아이들 모두에게 붙여주기 (함께 한 일)'));
      await tester.pumpAndSettle();
      expect(praises.addedToAll.single.$1, ['k1', 'k2']);
      expect(praises.addedToAll.single.$2, '같이 청소했어요');
      expect(find.text('👫 모두에게 스티커를 붙였어요'), findsOneWidget);
    });

    testWidgets('아이가 1명이면 pill 1개, 모두에게 버튼 없음', (tester) async {
      members.members = const [_mom, _harin];
      await pump(tester, _mom);
      expect(find.byKey(const ValueKey('kid-pill-k1')), findsOneWidget);
      expect(find.text('👫 아이들 모두에게 붙여주기 (함께 한 일)'), findsNothing);
    });

    testWidgets('목표 달성 시 보상 버튼 → claimReward + 새 판 안내', (tester) async {
      praises.praisesByBoard['b1'] = _entries('b1', 10);
      await pump(tester, _mom);

      expect(find.text('🎯 10개 모으면: 보드게임 사기 (10/10)'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('praise-slot-filled')), findsNWidgets(10));
      final reward = find.text('🎁 약속 지켰어요! 새 판 시작하기');
      expect(reward, findsOneWidget);

      await tester.tap(reward);
      await tester.pumpAndSettle();
      expect(praises.claimed.single.id, 'b1');
      expect(find.text('🎁 새 칭찬판이 시작됐어요'), findsOneWidget);
      // 새 판(기록 0개)이라 보상 버튼은 사라진다
      expect(reward, findsNothing);
      expect(find.text('🎯 10개 모으면: 보드게임 사기 (0/10)'), findsOneWidget);
    });

    testWidgets('목표 저장: saveGoal 호출 + 진행도 문구 갱신', (tester) async {
      await pump(tester, _mom);
      final goal = find.byKey(const ValueKey('goal-input'));
      await scrollTo(tester, goal);
      expect(tester.widget<TextField>(goal).controller!.text, '보드게임 사기');

      await tester.enterText(goal, '레고 사기');
      await tester.tap(find.text('목표 저장'));
      await tester.pumpAndSettle();
      expect(praises.savedGoals, [('b1', '레고 사기')]);
      await tester.scrollUntilVisible(
          find.text('🎯 10개 모으면: 레고 사기 (3/10)'), -200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('🎯 목표를 저장했어요'), findsOneWidget);
    });

    testWidgets('아이가 없으면 안내 문구만', (tester) async {
      members.members = const [_mom];
      await pump(tester, _mom);
      expect(
          find.text("아이를 먼저 추가해 주세요. '가족' 탭에서 아이를 추가할 수 있어요."), findsOneWidget);
      expect(find.byKey(const ValueKey('praise-input')), findsNothing);
      expect(praises.fetchedKids, isEmpty);
    });

    testWidgets('칭찬판이 없으면 안내', (tester) async {
      praises.boardsByKid = {};
      await pump(tester, _mom);
      expect(find.text('아직 칭찬판이 없어요'), findsOneWidget);
      expect(find.byKey(const ValueKey('praise-input')), findsNothing);
      expect(find.text('칭찬 기록'), findsNothing);
    });

    testWidgets('불러오기 실패면 에러 문구', (tester) async {
      praises.fetchError = Exception('x');
      await pump(tester, _mom);
      expect(find.text('칭찬판을 불러오지 못했어요'), findsOneWidget);
    });

    testWidgets('기록이 없으면 빈 기록 안내', (tester) async {
      praises.praisesByBoard['b1'] = [];
      await pump(tester, _mom);
      await scrollTo(tester, find.text('아직 칭찬 기록이 없어요'));
      expect(find.text('아직 칭찬 기록이 없어요'), findsOneWidget);
    });
  });

  group('아이', () {
    testWidgets('CRITICAL: 본인 칭찬판만, 입력 UI 전부 숨김 + 보기만 배지', (tester) async {
      await pump(tester, _harin);

      expect(praises.fetchedKids, ['k1']);
      expect(find.text('⭐ 하린의 칭찬 스티커'), findsOneWidget);
      expect(find.text('🎯 10개 모으면: 보드게임 사기 (3/10)'), findsOneWidget);
      expect(
          find.text('🔒 칭찬 스티커는 엄마, 아빠가 붙여줄 수 있어요. 열심히 해보자!'), findsOneWidget);
      expect(find.text('보기만 가능'), findsOneWidget);

      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const ValueKey('kid-pill-k1')), findsNothing);
      expect(find.byKey(const ValueKey('kid-pill-k2')), findsNothing);
      expect(find.text('🎯 목표 바꾸기'), findsNothing);
      expect(find.textContaining('붙여주기'), findsNothing);
      // 형제(준)의 이름/진행도는 어디에도 없음
      expect(find.textContaining('준'), findsNothing);
      expect(find.textContaining('7/10'), findsNothing);

      await scrollTo(tester, find.text('칭찬 기록'));
      expect(find.text('칭찬 기록'), findsOneWidget);
    });

    testWidgets('목표를 달성해도 아이에게는 보상 버튼이 없다', (tester) async {
      praises.praisesByBoard['b1'] = _entries('b1', 10);
      await pump(tester, _harin);
      expect(find.text('🎯 10개 모으면: 보드게임 사기 (10/10)'), findsOneWidget);
      expect(find.text('🎁 약속 지켰어요! 새 판 시작하기'), findsNothing);
    });
  });
}
