import 'package:family_toktok/models/room.dart';
import 'package:family_toktok/screens/conversation_list_screen.dart';
import 'package:family_toktok/services/rooms_service.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'rooms_test_helpers.dart';

void main() {
  late FakeRoomsService rooms;

  Widget app() => Provider<RoomsService>.value(
        value: rooms,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: ConversationListScreen(me: mom)),
        ),
      );

  setUp(() {
    rooms = FakeRoomsService()
      ..summaries = [
        RoomSummary(
          room: familyRoom,
          name: '가족방',
          lastMessage: LastMessagePreview(
              body: '저녁 먹자', createdAt: DateTime.utc(2026, 10, 22)),
          hasUnread: true,
        ),
        const RoomSummary(
            room: harinRoom,
            name: '하린와의 대화',
            lastMessage: null,
            hasUnread: false),
      ];
  });

  testWidgets('방 카드: 이름, 마지막 메시지(없으면 안내), 안읽음 점', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('가족방'), findsOneWidget);
    expect(find.text('저녁 먹자'), findsOneWidget);
    expect(find.text('하린와의 대화'), findsOneWidget);
    expect(find.text('아직 대화가 없어요'), findsOneWidget);
    expect(find.byKey(const Key('unread-rf')), findsOneWidget);
    expect(find.byKey(const Key('unread-rk')), findsNothing);
  });

  testWidgets('방이 없으면 빈 안내', (tester) async {
    rooms.summaries = const [];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('아직 대화방이 없어요'), findsOneWidget);
  });

  testWidgets('카드를 누르면 채팅 화면으로 이동하고, 돌아오면 목록을 새로 읽는다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(rooms.fetchRoomsCalls, 1);

    await tester.tap(find.text('하린와의 대화'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('messageInput')), findsOneWidget);
    expect(rooms.markedRead, ['rk']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(rooms.fetchRoomsCalls, 2);
  });
}
