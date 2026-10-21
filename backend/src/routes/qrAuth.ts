import { createClient } from "@supabase/supabase-js";
import { Router } from "express";
import { z } from "zod";
import { ensureKidAuthUser } from "../lib/kidAuthUser";
import { findMemberByAuthUserId } from "../lib/members";
import { generateQrToken, qrTokenExpiresAt } from "../lib/qrToken";
import { createSupabaseAdminClient } from "../lib/supabaseAdmin";
import { AuthedRequest, verifyJwt } from "../middleware/verifyJwt";

const router = Router();

const issueSchema = z.object({
  kidMemberId: z.string().uuid(),
});

// POST /auth/qr/issue — 부모가 특정 아이 계정으로 로그인할 QR용 토큰 발급
router.post("/issue", verifyJwt, async (req: AuthedRequest, res) => {
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

  const { error: insertError } = await admin.from("qr_login_tokens").insert({
    family_id: parent.family_id,
    kid_member_id: kid.id,
    issued_by: parent.id,
    token,
    expires_at: expiresAt.toISOString(),
  });

  if (insertError) {
    res.status(500).json({ error: "failed to issue token" });
    return;
  }

  res.status(201).json({ token, expiresAt: expiresAt.toISOString() });
});

const redeemSchema = z.object({
  token: z.string().min(1),
});

// POST /auth/qr/redeem — 아이 기기가 QR을 스캔해 받은 토큰을 세션으로 교환
router.post("/redeem", async (req, res) => {
  const parsed = redeemSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid request", details: parsed.error.flatten() });
    return;
  }

  const admin = createSupabaseAdminClient();

  const { data: qrToken, error: tokenError } = await admin
    .from("qr_login_tokens")
    .select("id, kid_member_id, expires_at, used_at")
    .eq("token", parsed.data.token)
    .maybeSingle();

  if (tokenError || !qrToken) {
    res.status(404).json({ error: "token not found" });
    return;
  }

  if (qrToken.used_at) {
    res.status(409).json({ error: "token already used" });
    return;
  }

  if (new Date(qrToken.expires_at) < new Date()) {
    res.status(410).json({ error: "token expired" });
    return;
  }

  const { data: kid, error: kidError } = await admin
    .from("members")
    .select("id, auth_user_id")
    .eq("id", qrToken.kid_member_id)
    .maybeSingle();

  if (kidError || !kid) {
    res.status(404).json({ error: "kid member not found" });
    return;
  }

  const authUserId = await ensureKidAuthUser(admin, kid.id, kid.auth_user_id);

  const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email: `kid-${kid.id}@internal.familytoktok.local`,
  });

  if (linkError || !linkData) {
    res.status(500).json({ error: "failed to generate session" });
    return;
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
    res.status(500).json({ error: "failed to exchange session" });
    return;
  }

  await admin
    .from("qr_login_tokens")
    .update({ used_at: new Date().toISOString() })
    .eq("id", qrToken.id);

  res.status(200).json({
    accessToken: verifyData.session.access_token,
    refreshToken: verifyData.session.refresh_token,
    authUserId,
  });
});

export default router;
