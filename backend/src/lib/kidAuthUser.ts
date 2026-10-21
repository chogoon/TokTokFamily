import { SupabaseClient } from "@supabase/supabase-js";
import { randomBytes } from "crypto";

function syntheticEmail(memberId: string): string {
  return `kid-${memberId}@internal.familytoktok.local`;
}

/**
 * 아이 멤버에게 연결된 Supabase Auth 사용자를 반환한다. 없으면 새로 만든다.
 * Supabase Auth는 email/phone 없이 사용자를 만들 수 없어, 외부에 노출되지 않는
 * internal 도메인의 합성 이메일을 멤버 1명당 하나씩 발급해 사용한다.
 */
export async function ensureKidAuthUser(
  admin: SupabaseClient,
  memberId: string,
  existingAuthUserId: string | null
): Promise<string> {
  if (existingAuthUserId) {
    return existingAuthUserId;
  }

  const email = syntheticEmail(memberId);
  const password = randomBytes(32).toString("base64url");

  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { kid_member_id: memberId },
  });

  if (error || !data.user) {
    throw error ?? new Error("failed to create kid auth user");
  }

  const { error: updateError } = await admin
    .from("members")
    .update({ auth_user_id: data.user.id })
    .eq("id", memberId);

  if (updateError) {
    throw updateError;
  }

  return data.user.id;
}
