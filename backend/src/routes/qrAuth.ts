import rateLimit from "express-rate-limit";
import { Router } from "express";
import { z } from "zod";
import { findMemberByAuthUserId } from "../lib/members";
import { generateQrToken, generateShortCode, qrTokenExpiresAt } from "../lib/qrToken";
import { redeemQrLoginToken } from "../lib/qrLoginSession";
import { createSupabaseAdminClient } from "../lib/supabaseAdmin";
import { AuthedRequest, verifyJwt } from "../middleware/verifyJwt";

const router = Router();

const MAX_SHORT_CODE_ATTEMPTS = 5;

// Postgres unique_violation
const UNIQUE_VIOLATION = "23505";

const issueSchema = z.object({
  kidMemberId: z.string().uuid(),
});

// POST /auth/qr/issue — 부모가 특정 아이 계정으로 로그인할 QR용 토큰 + 숫자 코드를 함께 발급
router.post("/qr/issue", verifyJwt, async (req: AuthedRequest, res) => {
  const parsed = issueSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid request", details: parsed.error.flatten() });
    return;
  }

  const admin = createSupabaseAdminClient();
  const parent = await findMemberByAuthUserId(admin, req.authUserId!);

  if (!parent || parent.role !== "parent") {
    res.status(403).json({ error: "only parents can issue QR login tokens" });
    return;
  }

  const { data: kid, error: kidError } = await admin
    .from("members")
    .select("id, family_id, role, auth_user_id")
    .eq("id", parsed.data.kidMemberId)
    .maybeSingle();

  if (kidError || !kid || kid.family_id !== parent.family_id || kid.role !== "kid") {
    res.status(404).json({ error: "kid member not found in your family" });
    return;
  }

  const token = generateQrToken();
  const expiresAt = qrTokenExpiresAt();

  // 숫자 코드는 활성(미사용) 상태에서 유일해야 한다(부분 unique 인덱스).
  // 충돌 시(다른 발급분과 코드가 겹침) 몇 차례 재생성해 재시도한다.
  let shortCode = "";
  let insertError: { code?: string; message: string } | null = null;

  for (let attempt = 0; attempt < MAX_SHORT_CODE_ATTEMPTS; attempt++) {
    shortCode = generateShortCode();

    const { error } = await admin.from("qr_login_tokens").insert({
      family_id: parent.family_id,
      kid_member_id: kid.id,
      issued_by: parent.id,
      token,
      short_code: shortCode,
      expires_at: expiresAt.toISOString(),
    });

    if (!error) {
      insertError = null;
      break;
    }

    insertError = error;
    if (error.code !== UNIQUE_VIOLATION) {
      break;
    }
  }

  if (insertError) {
    res.status(500).json({ error: "failed to issue token" });
    return;
  }

  res.status(201).json({ token, shortCode, expiresAt: expiresAt.toISOString() });
});

const redeemSchema = z.object({
  token: z.string().min(1),
});

// POST /auth/qr/redeem — 아이 기기가 QR을 스캔해 받은 토큰을 세션으로 교환
router.post("/qr/redeem", async (req, res) => {
  const parsed = redeemSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid request", details: parsed.error.flatten() });
    return;
  }

  const admin = createSupabaseAdminClient();
  const result = await redeemQrLoginToken(admin, "token", parsed.data.token);
  res.status(result.status).json(result.body);
});

// 숫자 6자리는 100만 조합뿐이라 QR 토큰(24바이트 랜덤)보다 훨씬 추측하기
// 쉽다 — IP당 분당 요청 수를 엄격히 제한해 brute-force를 어렵게 만든다.
const codeRedeemRateLimit = rateLimit({
  windowMs: 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
});

const codeRedeemSchema = z.object({
  shortCode: z.string().length(6).regex(/^\d{6}$/),
});

// POST /auth/code/redeem — 아이 기기가 QR 대신 숫자 코드를 직접 입력해 세션 교환
router.post("/code/redeem", codeRedeemRateLimit, async (req, res) => {
  const parsed = codeRedeemSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid request", details: parsed.error.flatten() });
    return;
  }

  const admin = createSupabaseAdminClient();
  const result = await redeemQrLoginToken(admin, "short_code", parsed.data.shortCode);
  res.status(result.status).json(result.body);
});

export default router;
