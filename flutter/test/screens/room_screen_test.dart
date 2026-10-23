import 'package:family_toktok/models/chat_message.dart';
import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/screens/room_screen.dart';
import 'package:family_toktok/services/rooms_service.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:family_toktok/utils/daily_question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'rooms_test_helpers.dart';

void main() {
  late FakeRoomsService rooms;

  Widget app(Member me, String roomId) {
    return Provider<RoomsService>.value(
      value: rooms,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: RoomScreen(me: me, roomId: roomId, title: '테스트방'),
      ),
    );
  }

  setUp(() => rooms = FakeRoomsService());

  group('오늘의 가족 질문 배너', () {
    testWidgets('가족방이면 보인다', (tester) async {
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 가족 질문'), findsOneWidget);
      expect(find.text(pickDailyQuestion(DateTime.now())), findsOneWidget);
    });

    testWidgets('1:1방이면 보이지 않는다', (tester) async {
      await tester.pumpWidget(app(mom, 'rk'));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 가족 질문'), findsNothing);
    });
  });

  group('역할별 빠른답장 칩', () {
    testWidgets('아이에게는 아이 칩(긴급 2개 포함)이 보인다', (tester) async {
      await tester.pumpWidget(app(harin, 'rf'));
      await tester.pumpAndSettle();
      expect(find.text('🏫 학교 끝났어요!'), findsOneWidget);
      expect(find.text('🚨 데리러 와주세요', skipOffstage: false), findsOneWidget);
      expect(find.text('😢 도와주세요', skipOffstage: false), findsOneWidget);
      expect(find.text('잘 도착했니?', skipOffstage: false), findsNothing);
    });

    testWidgets('보호자에게는 보호자 칩만, 긴급 칩은 없다', (tester) async {
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();
      expect(find.text('잘 도착했니?'), findsOneWidget);
      expect(find.text('🚨 데리러 와주세요', skipOffstage: false), findsNothing);
      expect(find.text('🏫 학교 끝났어요!', skipOffstage: false), findsNothing);
    });

    testWidgets('일반 칩을 누르면 현재 방으로 일반 메시지를 보낸다', (tester) async {
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('잘 도착했니?'));
      await tester.pumpAndSettle();
      expect(rooms.sent.single.roomId, 'rf');
      expect(rooms.sent.single.body, '잘 도착했니?');
      expect(rooms.sent.single.isUrgent, isFalse);
    });
  });

  group('아이 긴급 칩', () {
    testWidgets('본인 1:1방을 찾아 긴급 전송 → 그 방으로 이동 + 안내 토스트', (tester) async {
      await tester.pumpWidget(app(harin, 'rf'));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 가족 질문'), findsOneWidget);

      final chip = find.text('🚨 데리러 와주세요');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(rooms.kidRoomLookups, 1);
      expect(rooms.sent.single.roomId, 'rk');
      expect(rooms.sent.single.isUrgent, isTrue);
      expect(find.text('🔔 엄마, 아빠에게 바로 알림이 갔어요!'), findsOneWidget);
      // 1:1방으로 바뀌었으므로 가족방 배너가 사라진다.
      expect(find.text('오늘의 가족 질문'), findsNothing);
      expect(rooms.markedRead, contains('rk'));
    });

    testWidgets('본인 방을 못 찾으면 전송하지 않고 안내한다', (tester) async {
      rooms.myKidRoomId = null;
      await tester.pumpWidget(app(harin, 'rf'));
      await tester.pumpAndSettle();
      final chip = find.text('😢 도와주세요');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(rooms.sent, isEmpty);
      expect(find.text('보낼 방을 찾지 못했어요'), findsOneWidget);
    });

    testWidgets('전송 실패면 실패 안내', (tester) async {
      rooms.sendError = Exception('network');
      await tester.pumpWidget(app(harin, 'rk'));
      await tester.pumpAndSettle();
      final chip = find.text('😢 도와주세요');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('알림을 보내지 못했어요'), findsOneWidget);
    });
  });

  group('반응', () {
    testWidgets('반응이 없으면 ❤️로 시작한다', (tester) async {
      rooms.messagesByRoom['rf'] = [msg('m1')];
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('react-m1')));
      await tester.pumpAndSettle();
      expect(rooms.toggles.single, ('m1', null, '❤️'));
    });

    testWidgets('내 반응이 ❤️면 👍로 순환하고, 개수를 보여준다', (tester) async {
      rooms.messagesByRoom['rf'] = [msg('m1')];
      rooms.reactions['m1'] = const [
        ReactionSummary(emoji: '❤️', memberIds: ['p1', 'k1']),
      ];
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();

      expect(find.text('❤️ 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('react-m1')));
      await tester.pumpAndSettle();
      expect(rooms.toggles.single, ('m1', '❤️', '👍'));
    });

    testWidgets('마지막(😂)에서 누르면 반응을 지운다', (tester) async {
      rooms.messagesByRoom['rf'] = [msg('m1')];
      rooms.reactions['m1'] = const [
        ReactionSummary(emoji: '😂', memberIds: ['p1']),
      ];
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('react-m1')));
      await tester.pumpAndSettle();
      expect(rooms.toggles.single, ('m1', '😂', null));
    });

    testWidgets('Realtime 반응 변경 신호가 오면 반응을 다시 읽는다', (tester) async {
      rooms.messagesByRoom['rf'] = [msg('m1')];
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();
      expect(find.text('👍 1'), findsNothing);

      rooms.reactions['m1'] = const [
        ReactionSummary(emoji: '👍', memberIds: ['k1']),
      ];
      rooms.emitReactionChange();
      await tester.pumpAndSettle();
      expect(find.text('👍 1'), findsOneWidget);
    });
  });

  group('메시지', () {
    testWidgets('상대 메시지에는 이름, 스티커/긴급 메시지를 그린다', (tester) async {
      rooms.messagesByRoom['rf'] = [
        msg('m1', body: '학교 끝!'),
        msg('m2', kind: MessageKind.sticker, body: '🎉'),
        msg('m3', body: '🚨 데리러 와주세요', isUrgent: true),
        msg('m4', senderId: 'p1', senderName: '엄마', body: '알겠어'),
      ];
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();

      expect(find.text('학교 끝!'), findsOneWidget);
      expect(find.text('🎉'), findsWidgets);
      expect(find.text('🚨 데리러 와주세요'), findsOneWidget);
      expect(find.text('알겠어'), findsOneWidget);
      // 내 메시지(엄마)에는 이름을 붙이지 않는다.
      expect(find.text('엄마'), findsNothing);
      expect(find.text('하린'), findsNWidgets(3));
    });

    testWidgets('메시지가 없으면 안내 문구', (tester) async {
      await tester.pumpWidget(app(mom, 'rk'));
      await tester.pumpAndSettle();
      expect(find.text('아직 대화가 없어요. 첫 메시지를 보내볼까요?'), findsOneWidget);
    });

    testWidgets('입장 시 읽음 처리하고, Realtime 새 메시지를 붙인다(중복 id는 무시)', (tester) async {
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();
      expect(rooms.markedRead, ['rf']);

      rooms.emitMessage(msg('m9', body: '새 메시지'));
      rooms.emitMessage(msg('m9', body: '새 메시지'));
      await tester.pumpAndSettle();
      expect(find.text('새 메시지'), findsOneWidget);
      expect(rooms.markedRead, ['rf', 'rf']);
    });

    testWidgets('입력 후 보내기 → 전송하고 입력창을 비운다, 빈 입력은 무시', (tester) async {
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('보내기'));
      await tester.pump();
      expect(rooms.sent, isEmpty);

      await tester.enterText(
          find.byKey(const Key('messageInput')), '  저녁 뭐 먹을까  ');
      await tester.pump(); // 입력이 생기면 보내기 버튼이 활성화된다
      await tester.tap(find.text('보내기'));
      await tester.pumpAndSettle();
      expect(rooms.sent.single.body, '저녁 뭐 먹을까');
      expect(find.text('  저녁 뭐 먹을까  '), findsNothing);
    });

    testWidgets('스티커 피커를 열어 고르면 스티커를 보내고 닫힌다', (tester) async {
      await tester.pumpWidget(app(harin, 'rf'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sticker-🐶')), findsNothing);

      await tester.tap(find.byKey(const Key('stickerToggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sticker-🐶')));
      await tester.pumpAndSettle();

      expect(rooms.stickersSent.single, ('rf', '🐶'));
      expect(find.byKey(const Key('sticker-🐶')), findsNothing);
    });

    testWidgets('화면을 닫으면 Realtime 구독을 해제한다', (tester) async {
      await tester.pumpWidget(app(mom, 'rf'));
      await tester.pumpAndSettle();
      expect(rooms.activeMessageSubscriptions, 1);
      await tester.pumpWidget(const SizedBox());
      expect(rooms.activeMessageSubscriptions, 0);
    });
  });
}
