import { backendPost } from "./api";
import { supabase } from "./supabase";

export interface IssueQrTokenResult {
  token: string;
  expiresAt: string;
}

export function issueQrToken(kidMemberId: string): Promise<IssueQrTokenResult> {
  return backendPost<IssueQrTokenResult>("/auth/qr/issue", { kidMemberId });
}

export interface RedeemQrTokenResult {
  accessToken: string;
  refreshToken: string;
  authUserId: string;
}

/** QR을 스캔한 아이 기기에서 호출한다. 응답 세션을 Supabase 클라이언트에 바로 반영한다. */
export async function redeemQrToken(token: string): Promise<RedeemQrTokenResult> {
  const result = await backendPost<RedeemQrTokenResult>(
    "/auth/qr/redeem",
    { token },
    { auth: false }
  );

  const { error } = await supabase.auth.setSession({
    access_token: result.accessToken,
    refresh_token: result.refreshToken,
  });
  if (error) {
    throw error;
  }

  return result;
}
