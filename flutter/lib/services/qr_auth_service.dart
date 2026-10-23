import '../models/qr_login_ticket.dart';
import 'api_client.dart';

/// redeem 응답의 세션을 Supabase 클라이언트에 반영한다. 테스트에서는 fake로 대체한다.
/// 실제 구현(`Supabase.instance.client.auth.setSession`)은 onAuthStateChange를 발생시켜
/// AuthController가 members를 다시 읽고 AuthGate가 홈으로 바뀐다.
typedef SessionApplier = Future<void> Function(
    String accessToken, String refreshToken);

/// 아이 기기 연결용 QR 토큰 + 6자리 코드 발급/교환 (backend 경유, ADR-004).
/// RN `frontend/services/qrAuth.ts`에 대응.
class QrAuthService {
  QrAuthService(this._api, {SessionApplier? applySession})
      : _applySession = applySession;

  final ApiClient _api;
  final SessionApplier? _applySession;

  /// `POST /auth/qr/issue` — 보호자만 호출 가능. 같은 가족의 아이가 아니면 404.
  Future<QrLoginTicket> issue(String kidMemberId) async {
    final json = await _api.post('/auth/qr/issue', {'kidMemberId': kidMemberId});
    return QrLoginTicket.fromJson(json);
  }

  /// `POST /auth/qr/redeem` — QR을 스캔한 아이 기기에서 호출 (인증 불필요).
  /// 404(없음)/409(이미 사용)/410(만료)은 [ApiError]로 던진다.
  Future<void> redeemQrToken(String token) =>
      _redeem('/auth/qr/redeem', {'token': token});

  /// `POST /auth/code/redeem` — 6자리 숫자 코드를 입력한 아이 기기에서 호출 (인증 불필요).
  /// 404/409/410 외에 IP당 분당 시도 제한을 넘으면 429.
  Future<void> redeemShortCode(String shortCode) =>
      _redeem('/auth/code/redeem', {'shortCode': shortCode});

  // 두 redeem 경로는 요청 경로/본문만 다르고 세션 적용은 같다 (RN `applySession`).
  Future<void> _redeem(String path, Map<String, Object?> body) async {
    final json = await _api.post(path, body, auth: false);
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    if (access is! String || refresh is! String) {
      throw const ApiError(500, 'session missing in redeem response');
    }
    final apply = _applySession;
    if (apply == null) {
      throw StateError('QrAuthService was created without applySession');
    }
    await apply(access, refresh);
  }
}
