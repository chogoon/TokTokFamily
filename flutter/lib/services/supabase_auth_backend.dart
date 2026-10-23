import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';
import '../state/auth_controller.dart';

/// AuthController가 쓰는 Supabase 직접 호출 구현. RN `services/members.ts`, `services/supabase.ts`에 대응.
/// members/families 조회는 anon key + 사용자 JWT로 하므로 RLS가 family 범위를 제한한다.
class SupabaseAuthBackend implements AuthBackend {
  SupabaseAuthBackend(this._client);

  final SupabaseClient _client;

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  Stream<bool> get sessionChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<Member?> fetchCurrentMember() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('members')
        .select('id, family_id, role, name, avatar, color')
        .eq('auth_user_id', user.id)
        .maybeSingle();
    return row == null ? null : Member.fromRow(row);
  }

  @override
  Future<String?> fetchFamilyName(String familyId) async {
    final row = await _client
        .from('families')
        .select('name')
        .eq('id', familyId)
        .maybeSingle();
    return row?['name'] as String?;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

/// 보호자 계정 가입/로그인 (이메일+비밀번호). 아이 계정은 이 경로를 쓰지 않는다 (QR/코드 로그인 — 다음 단계).
class ParentAuthService {
  ParentAuthService(this._client);

  final SupabaseClient _client;

  /// 로컬 Supabase 기본값(이메일 확인 비활성화)에서는 가입 즉시 세션이 생긴다.
  /// 이메일 확인이 켜진 환경이면 세션이 null이라 false를 돌려준다.
  Future<bool> signUp({required String email, required String password}) async {
    final res =
        await _client.auth.signUp(email: email.trim(), password: password);
    return res.session != null;
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth
        .signInWithPassword(email: email.trim(), password: password);
  }

  Future<String?> accessToken() async =>
      _client.auth.currentSession?.accessToken;
}
