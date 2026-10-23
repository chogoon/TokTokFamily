export interface Member {
  id: string;
  familyId: string;
  role: "parent" | "kid";
  name: string;
  avatar: string | null;
  color: string | null;
}
