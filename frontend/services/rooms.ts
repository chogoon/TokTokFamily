import { buildRoomSummaries, pickLastMessagePerRoom } from "../lib/rooms";
import { Member } from "../types/member";
import { Message } from "../types/message";
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

/** 현재 member 명의로 텍스트 메시지를 보낸다. */
export async function sendMessage(roomId: string, body: string): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    throw new Error("로그인이 필요해요");
  }

  const { error } = await supabase.from("messages").insert({
    room_id: roomId,
    sender_id: currentMember.id,
    kind: "text",
    body,
  });
  if (error) {
    throw error;
  }
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
