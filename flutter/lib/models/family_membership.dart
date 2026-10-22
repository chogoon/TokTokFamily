/// `POST /families`, `POST /families/invites/redeem` 응답 (둘 다 같은 형태).
class FamilyMembership {
  const FamilyMembership({required this.familyId, required this.memberId});

  final String familyId;
  final String memberId;

  factory FamilyMembership.fromJson(Map<String, dynamic> json) {
    return FamilyMembership(
      familyId: json['familyId'] as String,
      memberId: json['memberId'] as String,
    );
  }
}
