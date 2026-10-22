import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { ensureKidAuthUser } from "./kidAuthUser";

export type RedeemResult =
  | { status: 404; body: { error: string } }
  | { status: 409; body: { error: string } }
  | { status: 410; body: { error: string } }
  | { status: 500; body: { error: string } }
  | {
      status: 200;
      body: { accessToken: string; refreshToken: string; authUserId: string };
    };

/**
 * `qr_login_tokens`를 주어진 컬럼(`token` 또는 `short_code`)과 값으로 조회해
 * 유효성(존재/재사용/만료)을 검증하고, 통과하면 아이 계정 세션으로 교환한다.
 *
 * QR 스캔(`/auth/qr/redeem`, 컬럼 `token`)과 숫자 코드 입력
 * (`/auth/code/redeem`, 컬럼 `short_code`)이 조회 컬럼만 다르고 나머지
 * 로직(만료/재사용 검증, 합성 이메일 magiclink 발급, verifyOtp로 세션 교환,
 * used_at 마킹)은 동일해 공유 헬퍼로 추출했다.
 */
export async function redeemQrLoginToken(
  admin: SupabaseClient,
  column: "token" | "short_code",
  value: string
): Promise<RedeemResult> {
  // `short_code`는 "미사용(used_at is null)" 상태에서만 유일성이 보장되는
  // 부분 unique 인덱스를 쓴다(20261022050000_add_qr_short_code.sql). 시간이
  // 지나 같은 6자리 코드가 과거에 이미 사용된 행으로 여러 번 누적된 상태에서
  // 그 코드가 다시 활성(미사용) 상태로 발급되면, 이 조회는 여러 행을
  // 매칭한다. `.maybeSingle()`은 그 경우 PGRST116 에러를 내므로, 대신
  // 배열로 받아 애플리케이션에서 "미사용 우선, 그 다음 가장 최근 발급분"
  // 순으로 하나를 고른다. (`token` 컬럼은 전역 unique라 항상 0~1행만
  // 매칭되므로 이 로직은 그 경로에서도 안전하게 동작한다.)
  const { data: candidates, error: tokenError } = await admin
    .from("qr_login_tokens")
    .select("id, kid_member_id, expires_at, used_at, created_at")
    .eq(column, value)
    .order("created_at", { ascending: false });

  if (tokenError) {
    return { status: 404, body: { error: "token not found" } };
  }

  const rows = candidates ?? [];
  const activeRows = rows.filter((row) => !row.used_at);
  // 활성(미사용) 행이 있으면 그중 가장 최근 발급분을, 전부 사용됐으면
  // 가장 최근에 사용된 행을 기준으로 404/409/410을 판단한다.
  const qrToken = activeRows.length > 0 ? activeRows[0] : rows[0];

  if (!qrToken) {
    return { status: 404, body: { error: "token not found" } };
  }

  if (qrToken.used_at) {
    return { status: 409, body: { error: "token already used" } };
  }

  if (new Date(qrToken.expires_at) < new Date()) {
    return { status: 410, body: { error: "token expired" } };
  }

  const { data: kid, error: kidError } = await admin
    .from("members")
    .select("id, auth_user_id")
    .eq("id", qrToken.kid_member_id)
    .maybeSingle();

  if (kidError || !kid) {
    return { status: 404, body: { error: "kid member not found" } };
  }

  const authUserId = await ensureKidAuthUser(admin, kid.id, kid.auth_user_id);

  const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email: `kid-${kid.id}@internal.familytoktok.local`,
  });

  if (linkError || !linkData) {
    return { status: 500, body: { error: "failed to generate session" } };
  }

  const anon = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );

  const { data: verifyData, error: verifyError } = await anon.auth.verifyOtp({
    type: "magiclink",
    token_hash: linkData.properties.hashed_token,
  });

  if (verifyError || !verifyData.session) {
    return { status: 500, body: { error: "failed to exchange session" } };
  }

  await admin
    .from("qr_login_tokens")
    .update({ used_at: new Date().toISOString() })
    .eq("id", qrToken.id);

  return {
    status: 200,
    body: {
      accessToken: verifyData.session.access_token,
      refreshToken: verifyData.session.refresh_token,
      authUserId,
    },
  };
}
