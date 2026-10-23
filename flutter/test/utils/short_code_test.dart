import 'package:family_toktok/utils/short_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatShortCode', () {
    test('6자리 숫자 코드를 가운데 공백을 넣어 "482 913" 형태로 표시한다', () {
      expect(formatShortCode('482913'), '482 913');
    });

    test('6자리가 아니면 그대로 반환한다', () {
      expect(formatShortCode('12345'), '12345');
      expect(formatShortCode(''), '');
    });
  });

  group('sanitizeShortCodeInput', () {
    test('숫자만 남긴다 (공백/하이픈/문자 제거)', () {
      expect(sanitizeShortCodeInput('482 913'), '482913');
      expect(sanitizeShortCodeInput('48-2a9b13'), '482913');
      expect(sanitizeShortCodeInput('abc'), '');
    });

    test('최대 6자리로 자른다', () {
      expect(sanitizeShortCodeInput('1234567890'), '123456');
    });

    test('짧은 입력은 그대로 둔다', () {
      expect(sanitizeShortCodeInput('12'), '12');
      expect(sanitizeShortCodeInput(''), '');
    });

    test('전각/다른 문자 체계 숫자는 버린다 (ASCII 0-9만)', () {
      expect(sanitizeShortCodeInput('１２3'), '3');
    });
  });

  group('isCompleteShortCode', () {
    test('정확히 6자리 숫자면 true', () {
      expect(isCompleteShortCode('482913'), isTrue);
      expect(isCompleteShortCode('000000'), isTrue);
    });

    test('길이가 다르거나 숫자가 아니면 false', () {
      expect(isCompleteShortCode('48291'), isFalse);
      expect(isCompleteShortCode('4829130'), isFalse);
      expect(isCompleteShortCode('48291a'), isFalse);
      expect(isCompleteShortCode('482 13'), isFalse);
      expect(isCompleteShortCode(''), isFalse);
    });
  });
}
