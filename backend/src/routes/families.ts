import { Router } from "express";
import { z } from "zod";
import { createSupabaseAdminClient } from "../lib/supabaseAdmin";
import { generateInviteCode, inviteExpiresAt } from "../lib/inviteCode";
import { findMemberByAuthUserId } from "../lib/members";
import { verifyJwt, AuthedRequest } from "../middleware/verifyJwt";

const router = Router();

const createFamilySchema = z.object({
  familyName: z.string().min(1).max(100),
  parentName: z.string().min(1).max(100),
});

// POST /families — 가족 생성 + 요청자를 최초 보호자로 부트스트랩
router.post("/", verifyJwt, async (req: AuthedRequest, res) => {
  const parsed = createFamilySchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid request", details: parsed.error.flatten() });
    return;
  }

  const admin = createSupabaseAdminClient();
  const { data, error } = await admin.rpc("create_family_with_parent", {
    p_auth_user_id: req.authUserId,
    p_family_name: parsed.data.familyName,
    p_parent_name: parsed.data.parentName,
  });

  if (error) {
    if (error.message.includes("ALREADY_MEMBER")) {
      res.status(409).json({ error: "already a member of a family" });
      return;
    }
    res.status(500).json({ error: "failed to create family" });
    return;
  }

  const row = Array.isArray(data) ? data[0] : data;
  res.status(201).json({ familyId: row.family_id, memberId: row.member_id });
});

// POST /invites — 초대 코드 발급 (호출자가 보호자여야 함)
router.post("/invites", verifyJwt, async (req: AuthedRequest, res) => {
  const admin = createSupabaseAdminClient();
  const member = await findMemberByAuthUserId(admin, req.authUserId!);

  if (!member) {
    res.status(404).json({ error: "member not found" });
    return;
  }

  if (member.role !== "parent") {
    res.status(403).json({ error: "only parents can create invites" });
    return;
  }

  const code = generateInviteCode();
  const expiresAt = inviteExpiresAt();

  const { error } = await admin.from("invites").insert({
    family_id: member.family_id,
    code,
    created_by: member.id,
    expires_at: expiresAt.toISOString(),
  });

  if (error) {
    res.status(500).json({ error: "failed to create invite" });
    return;
  }

  res.status(201).json({ code, expiresAt: expiresAt.toISOString() });
});

const redeemInviteSchema = z.object({
  code: z.string().min(1),
  parentName: z.string().min(1).max(100),
});

// POST /invites/redeem — 초대 코드로 보호자 가입
router.post("/invites/redeem", verifyJwt, async (req: AuthedRequest, res) => {
  const parsed = redeemInviteSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid request", details: parsed.error.flatten() });
    return;
  }

  const admin = createSupabaseAdminClient();
  const { data, error } = await admin.rpc("redeem_invite", {
    p_code: parsed.data.code,
    p_auth_user_id: req.authUserId,
    p_name: parsed.data.parentName,
  });

  if (error) {
    if (error.message.includes("INVITE_NOT_FOUND")) {
      res.status(404).json({ error: "invite not found" });
      return;
    }
    if (error.message.includes("INVITE_ALREADY_USED")) {
      res.status(409).json({ error: "invite already used" });
      return;
    }
    if (error.message.includes("INVITE_EXPIRED")) {
      res.status(410).json({ error: "invite expired" });
      return;
    }
    if (error.message.includes("ALREADY_MEMBER")) {
      res.status(409).json({ error: "already a member of a family" });
      return;
    }
    res.status(500).json({ error: "failed to redeem invite" });
    return;
  }

  const row = Array.isArray(data) ? data[0] : data;
  res.status(200).json({ familyId: row.family_id, memberId: row.member_id });
});

export default router;
