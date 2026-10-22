import { buildRoomSummaries, pickLastMessagePerRoom } from "../lib/rooms";
import { Member } from "../types/member";
import { Message, ReactionSummary } from "../types/message";
import { Room } from "../types/room";
import type { RoomSummary } from "../types/room";
import { fetchFamilyMembers } from "./family";
import { fetchCurrentMember } from "./members";
import { supabase } from "./supabase";

// 순수 로직(방 이름 계산, 안읽음 판정, 메시지 요약 합성)은 ../lib/rooms.ts에 있고
// 네트워크 없이 Jest로 테스트한다 (lib/rooms.test.ts). 이 파일은 Supabase 호출만 담당한다.

// ============================================================
// Supabase 직접 호출 (ADR-004 — RLS에 범위 제한을 맡긴다)
// ============================================================

/**
 * 현재 member가 접근 가능한 방 전체 + 각 방의 마지막 메시지 미리보기 + 안읽음 여부를 반환한다.
 * rooms/messages/reads 모두 필터 없이 select하고, RLS가 돌려준 결과만 그대로 쓴다.
 */
export async function fetchRooms(): Promise<RoomSummary[]> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    return [];
  }

  const members = await fetchFamilyMembers();

  const { data: roomRows, error: roomsError } = await supabase
    .from("rooms")
    .select("id, family_id, type, kid_member_id")
    .order("created_at", { ascending: true });
  if (roomsError) {
    throw roomsError;
  }

  const rooms: Room[] = (roomRows ?? []).map((row) => ({
    id: row.id,
    familyId: row.family_id,
    type: row.type,
    kidMemberId: row.kid_member_id,
  }));

  if (rooms.length === 0) {
    return [];
  }

  const roomIds = rooms.map((room) => room.id);

  const { data: messageRows, error: messagesError } = await supabase
    .from("messages")
    .select("room_id, body, created_at")
    .in("room_id", roomIds)
    .order("created_at", { ascending: false });
  if (messagesError) {
    throw messagesError;
  }

  const lastMessagesByRoom = pickLastMessagePerRoom(
    (messageRows ?? []).map((row) => ({
      roomId: row.room_id,
      body: row.body,
      createdAt: row.created_at,
    }))
  );

  const { data: readRows, error: readsError } = await supabase
    .from("reads")
    .select("room_id, last_read_at")
    .eq("member_id", currentMember.id);
  if (readsError) {
    throw readsError;
  }

  const lastReadAtByRoom: Record<string, string> = {};
  for (const row of readRows ?? []) {
    lastReadAtByRoom[row.room_id] = row.last_read_at;
  }

  return buildRoomSummaries(rooms, members, lastMessagesByRoom, lastReadAtByRoom);
}

/** 단일 방 정보를 id로 조회한다 (가족방 배너 노출 여부 등 화면 분기에 쓴다). RLS가 접근 범위를 제한한다. */
export async function fetchRoomById(roomId: string): Promise<Room | null> {
  const { data, error } = await supabase
    .from("rooms")
    .select("id, family_id, type, kid_member_id")
    .eq("id", roomId)
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
    type: data.type,
    kidMemberId: data.kid_member_id,
  };
}

/** 방의 메시지 전체를 시간 오름차순으로 조회하고, 보낸 사람 이름을 채운다. */
export async function fetchMessages(roomId: string): Promise<Message[]> {
  const { data, error } = await supabase
    .from("messages")
    .select("id, room_id, sender_id, kind, body, is_urgent, created_at")
    .eq("room_id", roomId)
    .order("created_at", { ascending: true });
  if (error) {
    throw error;
  }

  const rows = data ?? [];
  if (rows.length === 0) {
    return [];
  }

  const members = await fetchFamilyMembers();
  const nameById = new Map(members.map((member) => [member.id, member.name]));

  return rows.map((row) => ({
    id: row.id,
    roomId: row.room_id,
    senderId: row.sender_id,
    senderName: nameById.get(row.sender_id) ?? "가족",
    kind: row.kind,
    body: row.body,
    isUrgent: row.is_urgent,
    createdAt: row.created_at,
  }));
}

/** 현재 member 명의로 텍스트 메시지를 보낸다. `isUrgent`를 주면 긴급 메시지로 표시된다. */
export async function sendMessage(
  roomId: string,
  body: string,
  options?: { isUrgent?: boolean }
): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    throw new Error("로그인이 필요해요");
  }

  const { error } = await supabase.from("messages").insert({
    room_id: roomId,
    sender_id: currentMember.id,
    kind: "text",
    body,
    is_urgent: options?.isUrgent ?? false,
  });
  if (error) {
    throw error;
  }
}

/** 현재 member 명의로 긴급 텍스트 메시지를 보낸다. sendMessage(roomId, body, { isUrgent: true })와 동일하다. */
export async function sendUrgentMessage(roomId: string, body: string): Promise<void> {
  await sendMessage(roomId, body, { isUrgent: true });
}

/** 현재 member 명의로 스티커(이모지) 메시지를 보낸다. */
export async function sendSticker(roomId: string, emoji: string): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    throw new Error("로그인이 필요해요");
  }

  const { error } = await supabase.from("messages").insert({
    room_id: roomId,
    sender_id: currentMember.id,
    kind: "sticker",
    body: emoji,
  });
  if (error) {
    throw error;
  }
}

/**
 * 현재 로그인한 아이 본인의 1:1방 id를 반환한다 (없으면 null).
 * rooms를 type='kid'로만 필터해 select하고, RLS(rooms_select)가 "아이는 본인 kid_member_id가
 * 일치하는 방만, 부모는 전체" 돌려주므로 그 결과의 첫 행을 그대로 쓴다 — family_id나
 * kid_member_id로 클라이언트가 다시 필터링하지 않는다(그 흉내는 형제 방 유출로 이어질 수 있다).
 * 아이 역할이 아닌 member가 호출하면 RLS상 여러 아이의 방이 돌아올 수 있으므로,
 * 이 함수는 kid 역할 member가 호출할 때만 의미가 있다 (호출부에서 역할을 먼저 확인한다).
 */
export async function fetchMyKidRoomId(): Promise<string | null> {
  const { data, error } = await supabase
    .from("rooms")
    .select("id")
    .eq("type", "kid");
  if (error) {
    throw error;
  }

  return data?.[0]?.id ?? null;
}

/** 해당 방의 새 메시지를 Realtime으로 구독한다. 반환값을 호출하면 구독을 해제한다. */
export function subscribeToMessages(
  roomId: string,
  onInsert: (message: Message) => void
): () => void {
  let members: Member[] = [];
  let cancelled = false;

  fetchFamilyMembers()
    .then((result) => {
      if (!cancelled) {
        members = result;
      }
    })
    .catch(() => {
      // 이름 조회 실패해도 메시지 수신 자체는 막지 않는다 (기본 이름으로 표시).
    });

  const channel = supabase
    .channel(`messages-room-${roomId}`)
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "messages", filter: `room_id=eq.${roomId}` },
      (payload) => {
        const row = payload.new as {
          id: string;
          room_id: string;
          sender_id: string;
          kind: "text" | "sticker" | "system";
          body: string | null;
          is_urgent: boolean;
          created_at: string;
        };
        const sender = members.find((member) => member.id === row.sender_id);
        onInsert({
          id: row.id,
          roomId: row.room_id,
          senderId: row.sender_id,
          senderName: sender?.name ?? "가족",
          kind: row.kind,
          body: row.body,
          isUrgent: row.is_urgent,
          createdAt: row.created_at,
        });
      }
    )
    .subscribe();

  return () => {
    cancelled = true;
    supabase.removeChannel(channel);
  };
}

/** 주어진 메시지들에 달린 반응을 메시지id → 이모지별 묶음으로 반환한다. */
export async function fetchReactions(
  messageIds: string[]
): Promise<Record<string, ReactionSummary[]>> {
  if (messageIds.length === 0) {
    return {};
  }

  const { data, error } = await supabase
    .from("reactions")
    .select("message_id, member_id, emoji")
    .in("message_id", messageIds);
  if (error) {
    throw error;
  }

  const byMessage: Record<string, Record<string, string[]>> = {};
  for (const row of data ?? []) {
    byMessage[row.message_id] ||= {};
    byMessage[row.message_id][row.emoji] ||= [];
    byMessage[row.message_id][row.emoji].push(row.member_id);
  }

  const result: Record<string, ReactionSummary[]> = {};
  for (const [messageId, emojiMap] of Object.entries(byMessage)) {
    result[messageId] = Object.entries(emojiMap).map(([emoji, memberIds]) => ({
      emoji,
      memberIds,
    }));
  }
  return result;
}

/**
 * 메시지 하나에 대한 내 반응을 순환시킨다. "다음 이모지"는 lib/rooms.ts의
 * nextReactionEmoji(순수 함수, Jest로 테스트됨)가 계산하고, 이 함수는 그 결과에
 * 따라 내 기존 반응을 delete하고(있었다면) 새 반응이 있으면 insert만 한다.
 */
export async function toggleReaction(
  messageId: string,
  currentEmoji: string | undefined,
  nextEmoji: string | undefined
): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    throw new Error("로그인이 필요해요");
  }

  if (currentEmoji !== undefined) {
    const { error } = await supabase
      .from("reactions")
      .delete()
      .eq("message_id", messageId)
      .eq("member_id", currentMember.id)
      .eq("emoji", currentEmoji);
    if (error) {
      throw error;
    }
  }

  if (nextEmoji !== undefined) {
    const { error } = await supabase.from("reactions").insert({
      message_id: messageId,
      member_id: currentMember.id,
      emoji: nextEmoji,
    });
    if (error) {
      throw error;
    }
  }
}

/** 특정 방에 속한 메시지들의 반응 변경(추가/삭제)을 Realtime으로 구독한다. */
export function subscribeToReactions(
  messageIds: string[],
  onChange: () => void
): () => void {
  if (messageIds.length === 0) {
    return () => {};
  }

  const channel = supabase
    .channel(`reactions-${messageIds[0]}`)
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "reactions" },
      (payload) => {
        const row = payload.new as { message_id: string };
        if (messageIds.includes(row.message_id)) {
          onChange();
        }
      }
    )
    .on(
      "postgres_changes",
      { event: "DELETE", schema: "public", table: "reactions" },
      (payload) => {
        const row = payload.old as { message_id: string };
        if (messageIds.includes(row.message_id)) {
          onChange();
        }
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}

/** 현재 member의 이 방 읽음 시각을 지금 시각으로 갱신한다. */
export async function markRoomRead(roomId: string): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    return;
  }

  const { error } = await supabase.from("reads").upsert(
    {
      room_id: roomId,
      member_id: currentMember.id,
      last_read_at: new Date().toISOString(),
    },
    { onConflict: "room_id,member_id" }
  );
  if (error) {
    throw error;
  }
}
