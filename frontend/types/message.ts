export interface Message {
  id: string;
  roomId: string;
  senderId: string;
  senderName: string;
  kind: "text" | "sticker" | "system";
  body: string | null;
  isUrgent: boolean;
  createdAt: string;
}

/** 메시지 하나에 달린 반응을 이모지별로 묶은 결과 (누가 눌렀는지는 memberIds로). */
export interface ReactionSummary {
  emoji: string;
  memberIds: string[];
}
