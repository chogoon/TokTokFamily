import '../models/added_kid.dart';
import '../models/family_membership.dart';
import '../models/invite.dart';
import '../utils/validators.dart';
import 'api_client.dart';

/// 가족 생성/초대 발급·redeem/아이 추가 (backend 경유). RN `frontend/services/families.ts`에 대응.
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

  /// `POST /families/invites` — 보호자 초대 코드 발급. 호출자가 보호자여야 한다(아니면 403).
  Future<Invite> createInvite() async {
    final json = await _api.post('/families/invites', const {});
    return Invite.fromJson(json);
  }

  /// `POST /families/kids` — 아이 추가 (1:1 방 + 칭찬판이 함께 생긴다). 보호자만 가능.
  /// 아이에게는 이름(별명)/캐릭터/식별색 외의 정보를 보내지 않는다.
  Future<AddedKid> addKid({
    required String name,
    required String avatar,
    required String color,
  }) async {
    final json = await _api.post('/families/kids', {
      'name': name.trim(),
      'avatar': avatar,
      'color': color,
    });
    return AddedKid.fromJson(json);
  }
}
