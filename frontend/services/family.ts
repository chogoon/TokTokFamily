import { Member } from "../types/member";
import { supabase } from "./supabase";

/** 같은 가족 구성원 전체를 가져온다. RLS가 family_id로 범위를 제한한다. */
export async function fetchFamilyMembers(): Promise<Member[]> {
  const { data, error } = await supabase
    .from("members")
    .select("id, family_id, role, name, avatar, color")
    .order("created_at", { ascending: true });

  if (error) {
    throw error;
  }

  return (data ?? []).map((row) => ({
    id: row.id,
    familyId: row.family_id,
    role: row.role,
    name: row.name,
    avatar: row.avatar,
    color: row.color,
  }));
}
