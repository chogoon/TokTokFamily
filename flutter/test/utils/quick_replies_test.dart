import 'package:family_toktok/utils/quick_replies.dart';
import 'package:flutter_test/flutter_test.dart';

// RN frontend/lib/quickReplies.test.ts 포팅.
void main() {
  group('kidQuickReplies', () {
    test('7개이고 긴급 칩은 정확히 2개다 (데리러 와주세요 / 도와주세요)', () {
      expect(kidQuickReplies, hasLength(7));
      final urgent = kidQuickReplies.where((c) => c.urgent).map((c) => c.text);
      expect(urgent, ['🚨 데리러 와주세요', '😢 도와주세요']);
    });

    test('첫 칩은 학교 끝났어요', () {
      expect(kidQuickReplies.first.text, '🏫 학교 끝났어요!');
    });
  });

  group('parentQuickReplies', () {
    test('7개이고 긴급 칩이 없다', () {
      expect(parentQuickReplies, hasLength(7));
      expect(parentQuickReplies.every((c) => !c.urgent), isTrue);
    });
  });

  group('quickRepliesFor', () {
    test('아이면 아이 칩, 보호자면 보호자 칩', () {
      expect(quickRepliesFor(isKid: true), same(kidQuickReplies));
      expect(quickRepliesFor(isKid: false), same(parentQuickReplies));
    });
  });

  group('stickers', () {
    test('12개이고 중복이 없다', () {
      expect(stickers, hasLength(12));
      expect(stickers.toSet(), hasLength(12));
      expect(stickers.first, '🥰');
      expect(stickers.last, '🌈');
    });
  });
}
