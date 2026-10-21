import { backendPost } from "./api";

export interface CreateFamilyResult {
  familyId: string;
  memberId: string;
}

export function createFamily(
  familyName: string,
  parentName: string
): Promise<CreateFamilyResult> {
  return backendPost<CreateFamilyResult>("/families", { familyName, parentName });
}

export interface CreateInviteResult {
  code: string;
  expiresAt: string;
}

export function createInvite(): Promise<CreateInviteResult> {
  return backendPost<CreateInviteResult>("/families/invites", {});
}

export interface RedeemInviteResult {
  familyId: string;
  memberId: string;
}

export function redeemInvite(
  code: string,
  parentName: string
): Promise<RedeemInviteResult> {
  return backendPost<RedeemInviteResult>("/families/invites/redeem", {
    code,
    parentName,
  });
}
