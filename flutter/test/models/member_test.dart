import 'package:family_toktok/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase members 행(snake_case)을 Member로 변환한다', () {
    final member = Member.fromRow({
      'id': 'm1',
      'family_id': 'f1',
      'role': 'parent',
      'name': '엄마',
      'avatar': null,
      'color': null,
    });

    expect(member.id, 'm1');
    expect(member.familyId, 'f1');
    expect(member.role, MemberRole.parent);
    expect(member.isParent, isTrue);
    expect(member.name, '엄마');
    expect(member.avatar, isNull);
  });

  test('kid 역할과 avatar/color를 읽는다', () {
    final member = Member.fromRow({
      'id': 'm2',
      'family_id': 'f1',
      'role': 'kid',
      'name': '하린',
      'avatar': '🐰',
      'color': '#FFB547',
    });

    expect(member.role, MemberRole.kid);
    expect(member.isParent, isFalse);
    expect(member.avatar, '🐰');
    expect(member.color, '#FFB547');
  });

  test('알 수 없는 role이면 FormatException', () {
    expect(
      () => Member.fromRow({
        'id': 'm3',
        'family_id': 'f1',
        'role': 'admin',
        'name': 'x',
      }),
      throwsFormatException,
    );
  });
}
