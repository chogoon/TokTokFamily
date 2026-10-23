import { SupabaseClient } from "@supabase/supabase-js";

export interface PushTarget {
  pushToken: string;
  provider: "expo" | "fcm";
}

async function deviceTokensForMembers(
  admin: SupabaseClient,
  memberIds: string[]
): Promise<PushTarget[]> {
  if (memberIds.length === 0) {
    return [];
  }

  const { data, error } = await admin
    .from("devices")
    .select("push_token, provider")
    .in("member_id", memberIds);

  if (error) {
    throw error;
  }

  return (data ?? []).map((d) => ({
    pushToken: d.push_token,
    provider: d.provider,
  }));
}

/** 새 메시지의 수신자(같은 방의 발신자 제외 구성원) 기기 토큰을 가져온다. */
export async function recipientsForMessage(
  admin: SupabaseClient,
  roomId: string,
  senderId: string
): Promise<PushTarget[]> {
  const { data: room, error: roomError } = await admin
    .from("rooms")
    .select("id, family_id, type, kid_member_id")
    .eq("id", roomId)
    .maybeSingle();

  if (roomError || !room) {
    return [];
  }

  let memberIds: string[];

  if (room.type === "kid") {
    const { data: parents } = await admin
      .from("members")
      .select("id")
      .eq("family_id", room.family_id)
      .eq("role", "parent");
    memberIds = [...(parents ?? []).map((m) => m.id), room.kid_member_id].filter(
      (id): id is string => !!id
    );
  } else {
    const { data: members } = await admin
      .from("members")
      .select("id")
      .eq("family_id", room.family_id);
    memberIds = (members ?? []).map((m) => m.id);
  }

  return deviceTokensForMembers(
    admin,
    memberIds.filter((id) => id !== senderId)
  );
}

/** 새 칭찬(praise)의 수신자(해당 칭찬판의 아이) 기기 토큰을 가져온다. */
export async function recipientsForPraise(
  admin: SupabaseClient,
  boardId: string
): Promise<PushTarget[]> {
  const { data: board, error } = await admin
    .from("praise_boards")
    .select("kid_member_id")
    .eq("id", boardId)
    .maybeSingle();

  if (error || !board) {
    return [];
  }

  return deviceTokensForMembers(admin, [board.kid_member_id]);
}
