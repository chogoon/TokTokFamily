/// `public.members` 행. RN의 `frontend/types/member.ts`에 대응.
enum MemberRole { parent, kid }

class Member {
  const Member({
    required this.id,
    required this.familyId,
    required this.role,
    required this.name,
    this.avatar,
    this.color,
  });

  final String id;
  final String familyId;
  final MemberRole role;
  final String name;
  final String? avatar;
  final String? color;

  bool get isParent => role == MemberRole.parent;

  /// Supabase `members` 테이블의 snake_case 행을 변환한다.
  factory Member.fromRow(Map<String, dynamic> row) {
    return Member(
      id: row['id'] as String,
      familyId: row['family_id'] as String,
      role: _parseRole(row['role']),
      name: row['name'] as String,
      avatar: row['avatar'] as String?,
      color: row['color'] as String?,
    );
  }

  static MemberRole _parseRole(Object? value) {
    switch (value) {
      case 'parent':
        return MemberRole.parent;
      case 'kid':
        return MemberRole.kid;
      default:
        throw FormatException('unknown member role: $value');
    }
  }
}
