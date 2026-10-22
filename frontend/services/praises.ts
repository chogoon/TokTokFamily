import { sortPraisesByNewest } from "../lib/praises";
import { PraiseBoard, PraiseEntry } from "../types/praise";
import { fetchFamilyMembers } from "./family";
import { fetchCurrentMember } from "./members";
import { supabase } from "./supabase";

// 순수 로직(슬롯 계산, 목표 진행도 문구, 정렬)은 ../lib/praises.ts에 있고
// 네트워크 없이 Jest로 테스트한다 (lib/praises.test.ts). 이 파일은 Supabase 호출만 담당한다.
//
// CRITICAL: 1:1 방/가족방 알림은 services/rooms.ts를 import하지 않고 이 파일 안에서
// 직접 Supabase 쿼리로 구현한다 (동시 작업 중인 다른 에이전트가 services/rooms.ts를
// 수정하고 있어 import 시 충돌/불일치 위험이 있다).

function mapBoardRow(row: {
  id: string;
  kid_member_id: string;
  family_id: string;
  goal_text: string;
  target_count: number;
  status: "active" | "done";
}): PraiseBoard {
  return {
    id: row.id,
    kidMemberId: row.kid_member_id,
    familyId: row.family_id,
    goalText: row.goal_text,
    targetCount: row.target_count,
    status: row.status,
  };
}

/** 해당 아이의 진행 중(active) 칭찬판 1개를 조회한다. RLS가 본인/보호자만 돌려준다. */
export async function fetchActiveBoard(kidMemberId: string): Promise<PraiseBoard | null> {
  const { data, error } = await supabase
    .from("praise_boards")
    .select("id, kid_member_id, family_id, goal_text, target_count, status")
    .eq("kid_member_id", kidMemberId)
    .eq("status", "active")
    .maybeSingle();

  if (error) {
    throw error;
  }
  if (!data) {
    return null;
  }

  return mapBoardRow(data);
}

/** 해당 칭찬판의 기록을 최신순으로 조회하고, 준 사람 이름을 채운다. */
export async function fetchPraises(boardId: string): Promise<PraiseEntry[]> {
  const { data, error } = await supabase
    .from("praises")
    .select("id, board_id, giver_id, text, created_at")
    .eq("board_id", boardId);

  if (error) {
    throw error;
  }

  const rows = data ?? [];
  if (rows.length === 0) {
    return [];
  }

  const members = await fetchFamilyMembers();
  const nameById = new Map(members.map((member) => [member.id, member.name]));

  const entries: PraiseEntry[] = rows.map((row) => ({
    id: row.id,
    boardId: row.board_id,
    giverId: row.giver_id,
    giverName: nameById.get(row.giver_id) ?? "가족",
    text: row.text,
    createdAt: row.created_at,
  }));

  return sortPraisesByNewest(entries);
}

/** 그 아이의 1:1방을 찾아 알림 메시지를 보낸다(발견되지 않아도 조용히 무시 — 보호자에게 방해되지 않게). */
async function notifyKidRoom(kidMemberId: string, body: string, senderId: string): Promise<void> {
  const { data: roomRow, error: roomError } = await supabase
    .from("rooms")
    .select("id")
    .eq("type", "kid")
    .eq("kid_member_id", kidMemberId)
    .maybeSingle();

  if (roomError) {
    throw roomError;
  }
  if (!roomRow) {
    return;
  }

  const { error: messageError } = await supabase.from("messages").insert({
    room_id: roomRow.id,
    sender_id: senderId,
    kind: "system",
    body,
  });
  if (messageError) {
    throw messageError;
  }
}

/** 가족방(type='family')에 알림 메시지를 보낸다. RLS 결과의 첫 행을 가족방으로 쓴다. */
async function notifyFamilyRoom(body: string, senderId: string): Promise<void> {
  const { data: roomRow, error: roomError } = await supabase
    .from("rooms")
    .select("id")
    .eq("type", "family")
    .maybeSingle();

  if (roomError) {
    throw roomError;
  }
  if (!roomRow) {
    return;
  }

  const { error: messageError } = await supabase.from("messages").insert({
    room_id: roomRow.id,
    sender_id: senderId,
    kind: "system",
    body,
  });
  if (messageError) {
    throw messageError;
  }
}

/** 보호자가 특정 아이의 칭찬판에 칭찬 1건을 추가하고, 그 아이의 1:1방에 알린다. */
export async function addPraise(boardId: string, text: string): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    throw new Error("로그인이 필요해요");
  }

  const { data: boardRow, error: boardError } = await supabase
    .from("praise_boards")
    .select("kid_member_id")
    .eq("id", boardId)
    .maybeSingle();
  if (boardError) {
    throw boardError;
  }
  if (!boardRow) {
    throw new Error("칭찬판을 찾을 수 없어요");
  }

  const { error } = await supabase.from("praises").insert({
    board_id: boardId,
    giver_id: currentMember.id,
    text,
  });
  if (error) {
    throw error;
  }

  await notifyKidRoom(boardRow.kid_member_id, `⭐ 칭찬 스티커! "${text}"`, currentMember.id);
}

/** 보호자가 여러 아이의 칭찬판에 동시에 같은 칭찬을 추가하고, 가족방에 한 건만 알린다. */
export async function addPraiseToAllKids(kidMemberIds: string[], text: string): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    throw new Error("로그인이 필요해요");
  }

  const members = await fetchFamilyMembers();
  const nameById = new Map(members.map((member) => [member.id, member.name]));

  for (const kidMemberId of kidMemberIds) {
    const board = await fetchActiveBoard(kidMemberId);
    if (!board) {
      continue;
    }
    const { error } = await supabase.from("praises").insert({
      board_id: board.id,
      giver_id: currentMember.id,
      text,
    });
    if (error) {
      throw error;
    }
  }

  const names = kidMemberIds.map((id) => nameById.get(id) ?? "가족").join(", ");
  await notifyFamilyRoom(`⭐ ${names} 모두 칭찬 스티커! "${text}"`, currentMember.id);
}

/** 목표 달성 보상을 그 아이 1:1방에 알리고, 기존 판을 닫고 같은 목표로 새 판을 시작한다. */
export async function claimReward(board: PraiseBoard): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    throw new Error("로그인이 필요해요");
  }

  await notifyKidRoom(
    board.kidMemberId,
    `🎁 약속한 "${board.goalText}" 지킬게! 새 칭찬판 시작이야`,
    currentMember.id
  );

  const { error: updateError } = await supabase
    .from("praise_boards")
    .update({ status: "done" })
    .eq("id", board.id);
  if (updateError) {
    throw updateError;
  }

  const { error: insertError } = await supabase.from("praise_boards").insert({
    kid_member_id: board.kidMemberId,
    family_id: board.familyId,
    goal_text: board.goalText,
    target_count: board.targetCount,
  });
  if (insertError) {
    throw insertError;
  }
}

/** 보호자가 칭찬판의 목표 텍스트를 수정한다. */
export async function saveGoal(boardId: string, goalText: string): Promise<void> {
  const { error } = await supabase
    .from("praise_boards")
    .update({ goal_text: goalText })
    .eq("id", boardId);
  if (error) {
    throw error;
  }
}
