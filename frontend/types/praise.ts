export interface PraiseBoard {
  id: string;
  kidMemberId: string;
  familyId: string;
  goalText: string;
  targetCount: number;
  status: "active" | "done";
}

export interface PraiseEntry {
  id: string;
  boardId: string;
  giverId: string;
  giverName: string;
  text: string | null;
  createdAt: string;
}
