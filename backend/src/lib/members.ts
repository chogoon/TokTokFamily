import { SupabaseClient } from "@supabase/supabase-js";

export interface MemberRow {
  id: string;
  family_id: string;
  role: "parent" | "kid";
  name: string;
}

export async function findMemberByAuthUserId(
  admin: SupabaseClient,
  authUserId: string
): Promise<MemberRow | null> {
  const { data, error } = await admin
    .from("members")
    .select("id, family_id, role, name")
    .eq("auth_user_id", authUserId)
    .maybeSingle();

  if (error) {
    throw error;
  }

  return data ?? null;
}
