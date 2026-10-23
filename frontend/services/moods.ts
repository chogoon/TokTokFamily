import { formatDate } from "../lib/formatDate";
import { shouldNotifyParent } from "../lib/moods";
import { FamilyTodayMood, MoodEntry } from "../types/mood";
import { fetchCurrentMember } from "./members";
import { supabase } from "./supabase";

// 순수 로직(알림 여부/본인·보호자 공개 범위 판정/주간 배열 합성)은 ../lib/moods.ts에 있고
// 네트워크 없이 Jest로 테스트한다 (lib/moods.test.ts). 이 파일은 Supabase 호출만 담당한다.

// ============================================================
// Supabase 직접 호출 (ADR-004 — RLS에 범위 제한을 맡긴다, family_id 재필터링 없음)
// ============================================================

/**
 * 오늘(로컬 날짜) 가족 전체의 기분을 가져온다.
 * 이모지는 전체 공개(moods_select가 family_id만 체크), 이유(note)는 본인+보호자 것만
 * mood_notes RLS가 돌려주므로 그 결과를 그대로 합친다 — 클라이언트에서 다시 가리지 않는다
 * (화면에서는 canSeeNote로 한 번 더 확인해 실수로 노출하지 않는다).
 */
export async function fetchTodayMoods(): Promise<FamilyTodayMood[]> {
  const today = formatDate(new Date());

  const { data: moodRows, error: moodsError } = await supabase
    .from("moods")
    .select("id, member_id, date, emoji")
    .eq("date", today);
  if (moodsError) {
    throw moodsError;
  }

  const moods = moodRows ?? [];
  if (moods.length === 0) {
    return [];
  }

  const moodIds = moods.map((row) => row.id);
  const { data: noteRows, error: notesError } = await supabase
    .from("mood_notes")
    .select("mood_id, note")
    .in("mood_id", moodIds);
  if (notesError) {
    throw notesError;
  }

  const noteByMoodId = new Map((noteRows ?? []).map((row) => [row.mood_id, row.note]));

  return moods.map((row) => ({
    memberId: row.member_id,
    date: row.date,
    emoji: row.emoji,
    note: noteByMoodId.get(row.id) ?? null,
  }));
}

/** 특정 member의 최근 7일(오늘 포함) 기분 기록을 조회한다. */
export async function fetchMyWeeklyMoods(memberId: string): Promise<MoodEntry[]> {
  const today = new Date();
  const start = new Date(today);
  start.setDate(start.getDate() - 6);

  const { data: moodRows, error: moodsError } = await supabase
    .from("moods")
    .select("id, member_id, date, emoji")
    .eq("member_id", memberId)
    .gte("date", formatDate(start))
    .lte("date", formatDate(today));
  if (moodsError) {
    throw moodsError;
  }

  const moods = moodRows ?? [];
  if (moods.length === 0) {
    return [];
  }

  const moodIds = moods.map((row) => row.id);
  const { data: noteRows, error: notesError } = await supabase
    .from("mood_notes")
    .select("mood_id, note")
    .in("mood_id", moodIds);
  // mood_notes RLS가 본인/보호자가 아니면 행을 돌려주지 않을 수 있다 — 에러가 아니라 빈 결과로 처리한다.
  if (notesError) {
    throw notesError;
  }

  const noteByMoodId = new Map((noteRows ?? []).map((row) => [row.mood_id, row.note]));

  return moods.map((row) => ({
    id: row.id,
    memberId: row.member_id,
    date: row.date,
    emoji: row.emoji,
    note: noteByMoodId.get(row.id) ?? null,
  }));
}

/**
 * 현재 로그인한 member 명의로 오늘자 기분을 저장한다(재선택 시 upsert).
 * 아이 역할이고 선택한 이모지가 슬픔/화남이면 본인 1:1방에 알림 메시지를 보낸다.
 *
 * 주의: services/rooms.ts를 import하지 않고 이 파일 안에서 직접 구현한다 — 그 파일이
 * 다른 작업과 동시에 수정 중이라 공유 의존을 피한다. rooms를 type='kid'로 필터 없이
 * select하면 RLS가 로그인한 아이 본인의 1:1방만 돌려준다.
 */
export async function saveMood(emoji: string, note?: string): Promise<void> {
  const currentMember = await fetchCurrentMember();
  if (!currentMember) {
    throw new Error("로그인이 필요해요");
  }

  const today = formatDate(new Date());

  const { data: moodRow, error: moodError } = await supabase
    .from("moods")
    .upsert(
      {
        member_id: currentMember.id,
        family_id: currentMember.familyId,
        date: today,
        emoji,
      },
      { onConflict: "member_id,date" }
    )
    .select("id")
    .single();
  if (moodError) {
    throw moodError;
  }

  const trimmedNote = note?.trim();
  if (trimmedNote) {
    const { error: noteError } = await supabase
      .from("mood_notes")
      .upsert(
        {
          mood_id: moodRow.id,
          note: trimmedNote,
        },
        { onConflict: "mood_id" }
      );
    if (noteError) {
      throw noteError;
    }
  }

  if (currentMember.role === "kid" && shouldNotifyParent(emoji)) {
    await notifyParentOfMood(currentMember.id, emoji, trimmedNote);
  }
}

/** 아이 본인의 1:1방에 기분 알림 텍스트 메시지를 보낸다. (아이 역할일 때만 호출한다) */
async function notifyParentOfMood(
  memberId: string,
  emoji: string,
  note: string | undefined
): Promise<void> {
  const { data: roomRows, error: roomsError } = await supabase
    .from("rooms")
    .select("id")
    .eq("type", "kid");
  if (roomsError) {
    throw roomsError;
  }

  const kidRoom = roomRows?.[0];
  if (!kidRoom) {
    return;
  }

  const body = note ? `오늘 기분: ${emoji} — ${note}` : `오늘 기분: ${emoji}`;

  const { error: messageError } = await supabase.from("messages").insert({
    room_id: kidRoom.id,
    sender_id: memberId,
    kind: "text",
    body,
  });
  if (messageError) {
    throw messageError;
  }
}
