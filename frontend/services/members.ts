import { Member } from "../types/member";
import { supabase } from "./supabase";

/** 현재 로그인한 auth 사용자에 연결된 member 행을 가져온다. 아직 가족이 없으면 null. */
export async function fetchCurrentMember(): Promise<Member | null> {
  const { data: authData } = await supabase.auth.getUser();
  if (!authData.user) {
    return null;
  }

  const { data, error } = await supabase
    .from("members")
    .select("id, family_id, role, name, avatar, color")
    .eq("auth_user_id", authData.user.id)
    .maybeSingle();

  if (error) {
    throw error;
  }
  if (!data) {
    return null;
  }

  return {
    id: data.id,
    familyId: data.family_id,
    role: data.role,
    name: data.name,
    avatar: data.avatar,
    color: data.color,
  };
}
