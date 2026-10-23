import 'dart:convert';

import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/screens/family_screen.dart';
import 'package:family_toktok/services/api_client.dart';
import 'package:family_toktok/services/families_service.dart';
import 'package:family_toktok/services/members_service.dart';
import 'package:family_toktok/services/qr_auth_service.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class FakeMembersService implements MembersService {
  FakeMembersService(this.members);

  List<Member> members;
  int fetches = 0;

  @override
  Future<List<Member>> fetchFamilyMembers() async {
    fetches++;
    return List.of(members);
  }
}

const _mom = Member(id: 'p1', familyId: 'f1', role: MemberRole.parent, name: '엄마');
const _harin = Member(
    id: 'k1',
    familyId: 'f1',
    role: MemberRole.kid,
    name: '하린',
    avatar: '🐰',
    color: '#FFB547');

void main() {
  late List<http.Request> requests;
  late FakeMembersService members;

  Widget app(Member me, {Map<String, Object> Function(http.Request)? respond}) {
    requests = [];
    final api = ApiClient(
      baseUrl: 'http://localhost:4000',
      httpClient: MockClient((r) async {
        requests.add(r);
        final body = respond?.call(r) ?? <String, Object>{};
        return http.Response(jsonEncode(body), 201,
            headers: {'content-type': 'application/json'});
      }),
      accessTokenProvider: () async => 'jwt',
    );
    return MultiProvider(
      providers: [
        Provider<MembersService>.value(value: members),
        Provider<FamiliesService>.value(value: FamiliesService(api)),
        Provider<QrAuthService>.value(value: QrAuthService(api)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: FamilyScreen(me: me)),
      ),
    );
  }

  setUp(() => members = FakeMembersService([_mom, _harin]));

  testWidgets('구성원 이름/아바타와 보호자 배지를 보여준다', (tester) async {
    await tester.pumpWidget(app(_mom));
    await tester.pumpAndSettle();

    expect(find.text('엄마'), findsOneWidget);
    expect(find.text('하린'), findsOneWidget);
    expect(find.text('🐰'), findsWidgets);
    expect(find.text('보호자'), findsOneWidget);
  });

  testWidgets('보호자에게는 아이 카드의 QR 버튼, 초대/아이 추가 섹션이 보인다', (tester) async {
    await tester.pumpWidget(app(_mom));
    await tester.pumpAndSettle();

    expect(find.text('QR로 로그인 연결하기'), findsOneWidget);
    expect(find.text('초대 코드 만들기'), findsOneWidget);
    expect(find.text('가족에 추가'), findsOneWidget);
  });

  testWidgets('아이에게는 QR 버튼/초대/아이 추가 섹션이 보이지 않는다', (tester) async {
    await tester.pumpWidget(app(_harin));
    await tester.pumpAndSettle();

    expect(find.text('하린'), findsOneWidget);
    expect(find.text('QR로 로그인 연결하기'), findsNothing);
    expect(find.text('초대 코드 만들기'), findsNothing);
    expect(find.text('가족에 추가'), findsNothing);
  });

  testWidgets('초대 코드 만들기 → 받은 코드와 10분 안내를 보여준다', (tester) async {
    await tester.pumpWidget(app(_mom,
        respond: (_) =>
            {'code': 'ABCD2345', 'expiresAt': '2026-10-22T03:10:00.000Z'}));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('초대 코드 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초대 코드 만들기'));
    await tester.pumpAndSettle();

    expect(requests.single.url.path, '/families/invites');
    expect(find.text('ABCD2345'), findsOneWidget);
    expect(find.textContaining('10분 안에 입력해야 해요'), findsOneWidget);
  });

  testWidgets('아이 추가 → 선택한 아바타와 순환 색으로 요청하고 목록을 새로고침한다',
      (tester) async {
    await tester.pumpWidget(app(_mom,
        respond: (_) => {'memberId': 'k2', 'kidRoomId': 'r2'}));
    await tester.pumpAndSettle();
    expect(members.fetches, 1);

    await tester.enterText(find.byKey(const Key('kidNameField')), ' 도윤 ');
    await tester.ensureVisible(find.byKey(const Key('avatar-🦊')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('avatar-🦊')));
    await tester.pump();
    await tester.ensureVisible(find.text('가족에 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가족에 추가'));
    await tester.pumpAndSettle();

    final req = requests.single;
    expect(req.url.path, '/families/kids');
    // 기존 아이 1명 → KID_COLORS[1]
    expect(jsonDecode(req.body),
        {'name': '도윤', 'avatar': '🦊', 'color': '#6BCB77'});
    expect(members.fetches, 2);
  });

  testWidgets('이름이 비어 있으면 요청하지 않고 안내를 보여준다', (tester) async {
    await tester.pumpWidget(app(_mom));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('가족에 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가족에 추가'));
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
    expect(find.text('이름을 적어주세요'), findsOneWidget);
  });
}
