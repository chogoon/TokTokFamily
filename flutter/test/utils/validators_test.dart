import 'package:family_toktok/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateFamilyName', () {
    test('빈 값/공백만 있으면 에러 메시지를 돌려준다', () {
      expect(validateFamilyName(''), isNotNull);
      expect(validateFamilyName('   '), isNotNull);
    });

    test('100자를 넘으면 에러 (backend zod max(100)과 동일)', () {
      expect(validateFamilyName('가' * 101), isNotNull);
      expect(validateFamilyName('가' * 100), isNull);
    });

    test('정상 값이면 null', () {
      expect(validateFamilyName('우리가족'), isNull);
    });
  });

  group('validateParentName', () {
    test('빈 값이면 에러, 정상 값이면 null', () {
      expect(validateParentName(' '), isNotNull);
      expect(validateParentName('엄마'), isNull);
    });

    test('100자를 넘으면 에러', () {
      expect(validateParentName('a' * 101), isNotNull);
    });
  });

  group('normalizeInviteCode', () {
    test('앞뒤/중간 공백과 하이픈을 지우고 대문자로 바꾼다', () {
      expect(normalizeInviteCode('  abcd efgh '), 'ABCDEFGH');
      expect(normalizeInviteCode('abcd-efgh'), 'ABCDEFGH');
    });
  });

  group('validateInviteCode', () {
    test('정규화 후 8자리 허용 문자만 통과', () {
      expect(validateInviteCode('abcd efgh'), isNull);
      expect(validateInviteCode('ABCD2345'), isNull);
    });

    test('길이가 다르면 에러', () {
      expect(validateInviteCode(''), isNotNull);
      expect(validateInviteCode('ABC'), isNotNull);
      expect(validateInviteCode('ABCDEFGHJ'), isNotNull);
    });

    test('혼동 문자(I, O, 0, 1)나 특수문자가 있으면 에러', () {
      expect(validateInviteCode('ABCDEFGI'), isNotNull);
      expect(validateInviteCode('ABCDEFG0'), isNotNull);
      expect(validateInviteCode('ABCDEF!G'), isNotNull);
    });
  });

  group('validateEmail / validatePassword (보호자 계정 전용)', () {
    test('이메일 형식', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('parent'), isNotNull);
      expect(validateEmail('parent@example.com'), isNull);
      expect(validateEmail('  parent@example.com '), isNull);
    });

    test('비밀번호는 6자 이상 (Supabase Auth 기본 최소 길이)', () {
      expect(validatePassword('12345'), isNotNull);
      expect(validatePassword('123456'), isNull);
    });
  });
}
