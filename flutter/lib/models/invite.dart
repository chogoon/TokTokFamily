/// `POST /families/invites` 응답 — 보호자 초대 코드(8자리, 10분 후 만료).
class Invite {
  const Invite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  factory Invite.fromJson(Map<String, dynamic> json) {
    return Invite(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
