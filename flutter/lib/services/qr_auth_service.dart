import '../models/qr_login_ticket.dart';
import 'api_client.dart';

/// 아이 기기 연결용 QR 토큰 + 6자리 코드 발급 (backend 경유, ADR-004). RN `frontend/services/qrAuth.ts`에 대응.
/// 아이 기기 쪽 redeem(`/auth/qr/redeem`, `/auth/code/redeem`)은 아이 로그인 화면 단계에서 추가한다.
class QrAuthService {
  QrAuthService(this._api);

  final ApiClient _api;

  /// `POST /auth/qr/issue` — 보호자만 호출 가능. 같은 가족의 아이가 아니면 404.
  Future<QrLoginTicket> issue(String kidMemberId) async {
    final json = await _api.post('/auth/qr/issue', {'kidMemberId': kidMemberId});
    return QrLoginTicket.fromJson(json);
  }
}
