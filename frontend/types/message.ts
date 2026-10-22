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
