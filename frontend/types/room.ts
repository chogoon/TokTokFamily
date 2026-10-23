export interface Room {
  id: string;
  familyId: string;
  type: "family" | "kid";
  kidMemberId: string | null;
}

export interface RoomSummary extends Room {
  /** 방 이름 (가족방: "가족방", 1:1방: "{아이이름}와의 대화") */
  name: string;
  lastMessage: {
    body: string | null;
    createdAt: string;
  } | null;
  hasUnread: boolean;
}
