import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';
import '../utils/push_notifications.dart';

/// 푸시 토큰(devices) 등록/해제 경계. 테스트에서 fake로 대체한다.
abstract class DevicesService {
  Future<void> registerDevice(String pushToken, DevicePlatform platform);
  Future<void> unregisterDevice(String pushToken);
}

/// Supabase 직접 호출 (ADR-004 — devices RLS: member_id = current_member_id()만 체크).
/// RN `frontend/services/devices.ts`에 대응. 클라이언트에서 family_id 등으로 재필터링하지 않는다.
class SupabaseDevicesService implements DevicesService {
  SupabaseDevicesService(this._client, {required this.currentMember});

  final SupabaseClient _client;

  /// AuthController가 이미 읽어 둔 members 행 (RLS가 auth.uid()와의 일치를 다시 검증).
  final Future<Member?> Function() currentMember;

  /// devices에는 (member_id, push_token) unique 제약이 없어서, 같은 토큰이 중복으로
  /// 쌓이지 않도록 insert 전에 select로 먼저 확인한다 (경쟁 조건은 이 앱 규모에서 무시).
  /// 실패는 throw한다 — soft-fail은 호출자(PushDeviceRegistrar)가 담당.
  @override
  Future<void> registerDevice(String pushToken, DevicePlatform platform) async {
    final member = await currentMember();
    if (member == null) return;

    final existing = await _client
        .from('devices')
        .select('id')
        .eq('member_id', member.id)
        .eq('push_token', pushToken)
        .maybeSingle();
    if (existing != null) return;

    await _client.from('devices').insert({
      'member_id': member.id,
      'push_token': pushToken,
      'platform': platform.value,
      // CRITICAL: 컬럼 default는 'expo'. FCM 토큰임을 명시해야 backend가 올바르게 라우팅한다.
      'provider': pushProviderFcm,
    });
  }

  /// 로그아웃 등 필요 시 해당 토큰 행을 삭제한다. member_id 체크는 RLS가 담당한다.
  @override
  Future<void> unregisterDevice(String pushToken) async {
    await _client.from('devices').delete().eq('push_token', pushToken);
  }
}
