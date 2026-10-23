/// `POST /auth/qr/issue` 응답. [token]은 QR 이미지로만 인코딩하고 화면 텍스트/로그에 노출하지 않는다.
class QrLoginTicket {
  const QrLoginTicket({
    required this.token,
    required this.shortCode,
    required this.expiresAt,
  });

  final String token;
  final String shortCode;
  final DateTime expiresAt;

  factory QrLoginTicket.fromJson(Map<String, dynamic> json) {
    return QrLoginTicket(
      token: json['token'] as String,
      shortCode: json['shortCode'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  // 디버그 출력/에러 리포트에 토큰이 섞이지 않도록 token·shortCode를 가린다.
  @override
  String toString() => 'QrLoginTicket(expiresAt: $expiresAt)';
}
