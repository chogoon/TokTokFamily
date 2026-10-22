import '../utils/validators.dart';
import '../models/family_membership.dart';
import 'api_client.dart';

/// 가족 생성/초대 redeem (backend 경유). RN `frontend/services/families.ts`에 대응.
class FamiliesService {
  FamiliesService(this._api);

  final ApiClient _api;

  /// `POST /families` — 가족 생성 + 호출자를 최초 보호자로 등록. Supabase 세션 필요.
  Future<FamilyMembership> createFamily({
    required String familyName,
    required String parentName,
  }) async {
    final json = await _api.post('/families', {
      'familyName': familyName.trim(),
      'parentName': parentName.trim(),
    });
    return FamilyMembership.fromJson(json);
  }

  /// `POST /families/invites/redeem` — 초대 코드로 보호자 가입. Supabase 세션 필요.
  Future<FamilyMembership> redeemInvite({
    required String code,
    required String parentName,
  }) async {
    final json = await _api.post('/families/invites/redeem', {
      'code': normalizeInviteCode(code),
      'parentName': parentName.trim(),
    });
    return FamilyMembership.fromJson(json);
  }
}
