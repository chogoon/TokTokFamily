// 대화방 입력창 위 빠른 답장 칩 + 스티커 목록. RN `frontend/lib/quickReplies.ts` 포팅.
// 아이 칩 중 urgent 두 개는 일반 칩과 달리 "아이 자신의 1:1방"으로 긴급 전송된다 (room_screen.dart).

class QuickReply {
  const QuickReply(this.text, {this.urgent = false});

  final String text;
  final bool urgent;
}

const kidQuickReplies = <QuickReply>[
  QuickReply('🏫 학교 끝났어요!'),
  QuickReply('🏠 집에 도착했어요'),
  QuickReply('🍙 배고파요'),
  QuickReply('📚 숙제 다 했어요'),
  QuickReply('🥰 사랑해요'),
  QuickReply('🚨 데리러 와주세요', urgent: true),
  QuickReply('😢 도와주세요', urgent: true),
];

const parentQuickReplies = <QuickReply>[
  QuickReply('잘 도착했니?'),
  QuickReply('간식 냉장고에 있어 🍓'),
  QuickReply('오늘도 최고야 👍'),
  QuickReply('몇 시에 끝나?'),
  QuickReply('숙제는 했니?'),
  QuickReply('곧 집에 갈게!'),
  QuickReply('사랑해 💕'),
];

List<QuickReply> quickRepliesFor({required bool isKid}) =>
    isKid ? kidQuickReplies : parentQuickReplies;

const stickers = <String>[
  '🥰', '😆', '😭', '👍', '🎉', '💯', //
  '🐶', '🐱', '🍕', '🍦', '⚽', '🌈',
];
