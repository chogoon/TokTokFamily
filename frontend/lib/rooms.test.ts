import {
  buildRoomName,
  buildRoomSummaries,
  isRoomUnread,
  pickLastMessagePerRoom,
} from "./rooms";
import { Member } from "../types/member";
import { Room } from "../types/room";


const familyRoom: Room = {
  id: "room-family",
  familyId: "family-1",
  type: "family",
  kidMemberId: null,
};

const kidRoom: Room = {
  id: "room-kid-1",
  familyId: "family-1",
  type: "kid",
  kidMemberId: "member-kid-1",
};

const members: Member[] = [
  { id: "member-parent", familyId: "family-1", role: "parent", name: "엄마", avatar: null, color: null },
  { id: "member-kid-1", familyId: "family-1", role: "kid", name: "서아", avatar: "🐰", color: "#FFB547" },
];

describe("buildRoomName", () => {
  it("가족방은 '가족방'으로 표시한다", () => {
    expect(buildRoomName(familyRoom, members)).toBe("가족방");
  });

  it("1:1방은 '{아이이름}와의 대화'로 표시한다", () => {
    expect(buildRoomName(kidRoom, members)).toBe("서아와의 대화");
  });

  it("아이 정보를 찾지 못하면 기본 레이블을 쓴다", () => {
    const orphanRoom: Room = { ...kidRoom, kidMemberId: "unknown-member" };
    expect(buildRoomName(orphanRoom, members)).toBe("1:1 대화");
  });
});

describe("isRoomUnread", () => {
  it("마지막 메시지가 없으면 안읽음이 아니다", () => {
    expect(isRoomUnread(null, null)).toBe(false);
  });

  it("읽은 적이 없고 메시지가 있으면 안읽음이다", () => {
    expect(isRoomUnread("2026-10-22T10:00:00.000Z", null)).toBe(true);
  });

  it("마지막 메시지가 읽음 시각보다 이후면 안읽음이다", () => {
    expect(
      isRoomUnread("2026-10-22T10:00:00.000Z", "2026-10-22T09:00:00.000Z")
    ).toBe(true);
  });

  it("마지막 메시지가 읽음 시각보다 이전이거나 같으면 안읽음이 아니다", () => {
    expect(
      isRoomUnread("2026-10-22T09:00:00.000Z", "2026-10-22T10:00:00.000Z")
    ).toBe(false);
    expect(
      isRoomUnread("2026-10-22T10:00:00.000Z", "2026-10-22T10:00:00.000Z")
    ).toBe(false);
  });
});

describe("pickLastMessagePerRoom", () => {
  it("내림차순 입력에서 방별 첫 행(가장 최신)만 남긴다", () => {
    const result = pickLastMessagePerRoom([
      { roomId: "room-a", body: "최신", createdAt: "2026-10-22T10:00:00.000Z" },
      { roomId: "room-a", body: "이전", createdAt: "2026-10-22T09:00:00.000Z" },
      { roomId: "room-b", body: "b방 메시지", createdAt: "2026-10-22T08:00:00.000Z" },
    ]);

    expect(result).toEqual({
      "room-a": { body: "최신", createdAt: "2026-10-22T10:00:00.000Z" },
      "room-b": { body: "b방 메시지", createdAt: "2026-10-22T08:00:00.000Z" },
    });
  });

  it("빈 입력이면 빈 객체를 반환한다", () => {
    expect(pickLastMessagePerRoom([])).toEqual({});
  });
});

describe("buildRoomSummaries", () => {
  it("방/이름/마지막 메시지/안읽음 여부를 합성한다", () => {
    const summaries = buildRoomSummaries(
      [familyRoom, kidRoom],
      members,
      {
        "room-family": { body: "안녕", createdAt: "2026-10-22T10:00:00.000Z" },
      },
      {
        "room-family": "2026-10-22T09:00:00.000Z",
        "room-kid-1": "2026-10-22T09:00:00.000Z",
      }
    );

    expect(summaries).toEqual([
      {
        ...familyRoom,
        name: "가족방",
        lastMessage: { body: "안녕", createdAt: "2026-10-22T10:00:00.000Z" },
        hasUnread: true,
      },
      {
        ...kidRoom,
        name: "서아와의 대화",
        lastMessage: null,
        hasUnread: false,
      },
    ]);
  });
});
