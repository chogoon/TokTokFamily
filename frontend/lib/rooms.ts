// services/rooms.ts가 쓰는 순수 로직(네트워크 없음)만 모은다.
// Supabase 클라이언트(services/supabase.ts)를 import하지 않아야 Jest에서
// AsyncStorage 네이티브 모듈 없이도 테스트할 수 있다.
import { Member } from "../types/member";
import { Room, RoomSummary } from "../types/room";

/** 방 이름을 계산한다. 가족방은 고정, 1:1방은 아이 이름 기반. */
export function buildRoomName(room: Room, members: Member[]): string {
  if (room.type === "family") {
    return "가족방";
  }
  const kid = members.find((m) => m.id === room.kidMemberId);
  return kid ? `${kid.name}와의 대화` : "1:1 대화";
}

/** 마지막 메시지 시각이 마지막 읽음 시각보다 최신이면 안읽음으로 판정한다. */
export function isRoomUnread(
  lastMessageCreatedAt: string | null,
  lastReadAt: string | null
): boolean {
  if (!lastMessageCreatedAt) {
    return false;
  }
  if (!lastReadAt) {
    return true;
  }
  return new Date(lastMessageCreatedAt).getTime() > new Date(lastReadAt).getTime();
}

export interface LastMessagePreview {
  body: string | null;
  createdAt: string;
}

export interface RawMessageRow {
  roomId: string;
  body: string | null;
  createdAt: string;
}

/**
 * created_at 내림차순으로 정렬된 메시지 목록에서 방별 가장 최근 메시지를 뽑는다.
 * 입력 순서를 신뢰하므로(먼저 나오는 행이 최신) 호출 측이 정렬된 데이터를 넘겨야 한다.
 */
export function pickLastMessagePerRoom(
  rows: RawMessageRow[]
): Record<string, LastMessagePreview> {
  const result: Record<string, LastMessagePreview> = {};
  for (const row of rows) {
    if (!result[row.roomId]) {
      result[row.roomId] = { body: row.body, createdAt: row.createdAt };
    }
  }
  return result;
}

/** 메시지에 달 수 있는 반응 이모지 목록 (family-sns.html 프로토타입의 REACTS). */
export const REACTION_EMOJIS = ["❤️", "👍", "😂"] as const;

/**
 * 메시지 반응 순환 로직 (family-sns.html 프로토타입의 REACTS 순환과 동일).
 * 내 반응은 최대 1개다. 현재 반응(`currentEmoji`)이 없으면 첫 이모지로,
 * 있으면 목록의 다음 이모지로 바뀌고, 마지막 이모지에서 한 번 더 누르면
 * 반응 없음(undefined)으로 돌아간다. 호출 측(services/rooms.ts)은 이 값에
 * 따라 기존 반응 delete + (undefined가 아니면) 새 반응 insert만 수행한다.
 */
export function nextReactionEmoji(
  emojis: readonly string[],
  currentEmoji: string | undefined
): string | undefined {
  const currentIndex = currentEmoji === undefined ? -1 : emojis.indexOf(currentEmoji);
  const nextIndex = currentIndex + 1;
  return emojis[nextIndex];
}

/** rooms/members/마지막 메시지/읽음 상태를 합쳐 화면에 쓸 RoomSummary 목록을 만든다. */
export function buildRoomSummaries(
  rooms: Room[],
  members: Member[],
  lastMessagesByRoom: Record<string, LastMessagePreview>,
  lastReadAtByRoom: Record<string, string>
): RoomSummary[] {
  return rooms.map((room) => {
    const lastMessage = lastMessagesByRoom[room.id] ?? null;
    return {
      ...room,
      name: buildRoomName(room, members),
      lastMessage,
      hasUnread: isRoomUnread(lastMessage?.createdAt ?? null, lastReadAtByRoom[room.id] ?? null),
    };
  });
}
