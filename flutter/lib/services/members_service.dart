import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';

/// 가족 구성원 목록 조회 경계. 화면 테스트에서 fake로 대체할 수 있게 추상화한다.
abstract class MembersService {
  Future<List<Member>> fetchFamilyMembers();
}

/// Supabase 직접 조회 (ADR-004 "일상 데이터" 경로). RN `frontend/services/family.ts`에 대응.
/// RLS가 같은 family_id 행만 돌려주므로 클라이언트에서 family_id로 재필터링하지 않는다.
class SupabaseMembersService implements MembersService {
  SupabaseMembersService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Member>> fetchFamilyMembers() async {
    final rows = await _client
        .from('members')
        .select('id, family_id, role, name, avatar, color')
        .order('created_at', ascending: true);
    return rows.map(Member.fromRow).toList();
  }
}
