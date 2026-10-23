import { DevicePlatform } from "../lib/pushNotifications";
import { fetchCurrentMember } from "./members";
import { supabase } from "./supabase";

// ============================================================
// Supabase 직접 호출 (ADR-004 — devices RLS: member_id = current_member_id()만 체크.
// 클라이언트에서 family_id 등으로 재필터링하지 않는다.)
// ============================================================

/**
 * 현재 로그인한 member 명의로 push 토큰을 devices에 등록한다.
 * devices 테이블에는 (member_id, push_token) 복합 unique 제약이 없어서, 같은 토큰이
 * 중복으로 쌓이지 않도록 insert 전에 이미 있는지 select로 먼저 확인한다
 * (경쟁 조건은 이 앱 규모에서 신경 쓰지 않는다).
 */
export async function registerDevice(
  pushToken: string,
  platform: DevicePlatform
): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    return;
  }

  const { data: existing, error: selectError } = await supabase
    .from("devices")
    .select("id")
    .eq("member_id", currentMember.id)
    .eq("push_token", pushToken)
    .maybeSingle();
  if (selectError) {
    throw selectError;
  }
  if (existing) {
    return;
  }

  const { error: insertError } = await supabase.from("devices").insert({
    member_id: currentMember.id,
    push_token: pushToken,
    platform,
  });
  if (insertError) {
    throw insertError;
  }
}

/** 로그아웃 등 필요 시 해당 토큰 행을 삭제한다. member_id 체크는 RLS가 담당한다. */
export async function unregisterDevice(pushToken: string): Promise<void> {
  const { error } = await supabase.from("devices").delete().eq("push_token", pushToken);
  if (error) {
    throw error;
  }
}
