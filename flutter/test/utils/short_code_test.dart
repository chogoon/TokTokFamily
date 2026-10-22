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
}
