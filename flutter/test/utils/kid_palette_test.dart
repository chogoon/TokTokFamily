import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/utils/kid_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Member _member(String id, MemberRole role) =>
    Member(id: id, familyId: 'f1', role: role, name: id);

void main() {
  group('상수 (backend/src/lib/kidPalette.ts와 동일해야 함)', () {
    test('KID_COLORS 7개를 같은 순서로 가진다', () {
      expect(kidColors, [
        '#FFB547',
        '#6BCB77',
        '#B28DFF',
        '#FF9F68',
        '#4FC3C7',
        '#F48FB1',
        '#9CCC65',
      ]);
    });

    test('KID_AVATARS 10개를 같은 순서로 가진다', () {
      expect(kidAvatars,
          ['🐣', '🦖', '🐰', '🦊', '🐼', '🐯', '🐨', '🦄', '🐸', '🐧']);
    });
  });

  group('nextKidColor', () {
    test('기존 아이 수에 따라 KID_COLORS를 순서대로 고른다', () {
      expect(nextKidColor(0), '#FFB547');
      expect(nextKidColor(1), '#6BCB77');
      expect(nextKidColor(6), '#9CCC65');
    });

    test('7명을 넘으면 처음 색부터 순환한다', () {
      expect(nextKidColor(7), '#FFB547');
      expect(nextKidColor(15), '#6BCB77');
    });
  });

  group('countKids', () {
    test('보호자는 세지 않고 아이 멤버 수만 센다', () {
      final members = [
        _member('엄마', MemberRole.parent),
        _member('하린', MemberRole.kid),
        _member('아빠', MemberRole.parent),
        _member('도윤', MemberRole.kid),
      ];
      expect(countKids(members), 2);
      expect(countKids(const []), 0);
    });
  });

  group('isValidKidAvatar', () {
    test('KID_AVATARS에 있는 이모지만 허용한다', () {
      expect(isValidKidAvatar('🐰'), isTrue);
      expect(isValidKidAvatar('🐶'), isFalse);
      expect(isValidKidAvatar(''), isFalse);
    });
  });

  group('validateKidName', () {
    test('공백만 있으면 이름을 적어달라는 문구', () {
      expect(validateKidName('   '), '이름을 적어주세요');
    });

    test('앞뒤 공백 제외 8자 이하면 통과', () {
      expect(validateKidName(' 서아 '), isNull);
      expect(validateKidName('가나다라마바사아'), isNull);
    });

    test('8자를 넘으면 실패 (backend zod max 8)', () {
      expect(validateKidName('가나다라마바사아자'), '이름은 8자 이하로 적어주세요');
    });

    test('이모지처럼 UTF-16 2단위 문자도 JS length와 같은 기준으로 센다', () {
      // backend(zod)는 JS string length(UTF-16 code unit)로 센다 — Dart String.length와 같다.
      expect(validateKidName('🐰🐰🐰🐰'), isNull);
      expect(validateKidName('🐰🐰🐰🐰🐰'), '이름은 8자 이하로 적어주세요');
    });
  });

  group('parseHexColor', () {
    test('#RRGGBB를 불투명 Color로 변환한다', () {
      expect(parseHexColor('#FFB547'), const Color(0xFFFFB547));
      expect(parseHexColor('#6bcb77'), const Color(0xFF6BCB77));
    });

    test('null이거나 형식이 틀리면 null', () {
      expect(parseHexColor(null), isNull);
      expect(parseHexColor('red'), isNull);
      expect(parseHexColor('#FFF'), isNull);
    });
  });
}
