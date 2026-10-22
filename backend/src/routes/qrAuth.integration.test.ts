import request from "supertest";
import { beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../app";
import { isLocalSupabaseUp } from "../test/supabaseTestEnv";
import { adminClient, createAuthedUser } from "../test/testHelpers";

const app = createApp();

async function createFamilyWithKid() {
  const parent = await createAuthedUser();
  const familyRes = await request(app)
    .post("/families")
    .set("Authorization", `Bearer ${parent.accessToken}`)
    .send({ familyName: "QR Family", parentName: "Parent" });

  const admin = adminClient();
  const { data: kid, error } = await admin
    .from("members")
    .insert({
      family_id: familyRes.body.familyId,
      role: "kid",
      name: "Kid",
    })
    .select("id")
    .single();
  if (error) throw error;

  return { parent, familyId: familyRes.body.familyId, kidMemberId: kid.id as string };
}

describe("QR auth routes (requires local Supabase)", () => {
  beforeAll(async () => {
    const up = await isLocalSupabaseUp();
    if (!up) {
      throw new Error(
        "local Supabase is not running — run `npx supabase start` before `npm test`"
      );
    }
  });

  it("issues a QR token for a kid in the parent's family", async () => {
    const { parent, kidMemberId } = await createFamilyWithKid();

    const res = await request(app)
      .post("/auth/qr/issue")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ kidMemberId });

    expect(res.status).toBe(201);
    expect(res.body.token).toBeDefined();
  });

  it("rejects issuing a QR token for a kid in a different family", async () => {
    const { parent } = await createFamilyWithKid();
    const other = await createFamilyWithKid();

    const res = await request(app)
      .post("/auth/qr/issue")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ kidMemberId: other.kidMemberId });

    expect(res.status).toBe(404);
  });

  it("redeems a QR token into a kid session, and rejects reuse", async () => {
    const { parent, kidMemberId } = await createFamilyWithKid();

    const issueRes = await request(app)
      .post("/auth/qr/issue")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ kidMemberId });

    const redeemRes = await request(app)
      .post("/auth/qr/redeem")
      .send({ token: issueRes.body.token });

    expect(redeemRes.status).toBe(200);
    expect(redeemRes.body.accessToken).toBeDefined();

    const secondRedeemRes = await request(app)
      .post("/auth/qr/redeem")
      .send({ token: issueRes.body.token });

    expect(secondRedeemRes.status).toBe(409);
  });

  it("rejects an unknown token", async () => {
    const res = await request(app)
      .post("/auth/qr/redeem")
      .send({ token: "does-not-exist" });

    expect(res.status).toBe(404);
  });

  it("issues a 6-digit numeric shortCode alongside the QR token", async () => {
    const { parent, kidMemberId } = await createFamilyWithKid();

    const res = await request(app)
      .post("/auth/qr/issue")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ kidMemberId });

    expect(res.status).toBe(201);
    expect(res.body.shortCode).toMatch(/^\d{6}$/);
  });

  it("redeems a shortCode into a kid session via /auth/code/redeem, and rejects reuse", async () => {
    const { parent, kidMemberId } = await createFamilyWithKid();

    const issueRes = await request(app)
      .post("/auth/qr/issue")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ kidMemberId });

    const redeemRes = await request(app)
      .post("/auth/code/redeem")
      .send({ shortCode: issueRes.body.shortCode });

    expect(redeemRes.status).toBe(200);
    expect(redeemRes.body.accessToken).toBeDefined();
    expect(redeemRes.body.refreshToken).toBeDefined();
    expect(redeemRes.body.authUserId).toBeDefined();

    const secondRedeemRes = await request(app)
      .post("/auth/code/redeem")
      .send({ shortCode: issueRes.body.shortCode });

    expect(secondRedeemRes.status).toBe(409);
  });

  it("rejects an expired shortCode with 410", async () => {
    const { parent, kidMemberId } = await createFamilyWithKid();

    const issueRes = await request(app)
      .post("/auth/qr/issue")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ kidMemberId });

    const admin = adminClient();
    const pastDate = new Date(Date.now() - 60 * 1000).toISOString();
    const { error } = await admin
      .from("qr_login_tokens")
      .update({ expires_at: pastDate })
      .eq("short_code", issueRes.body.shortCode);
    if (error) throw error;

    const redeemRes = await request(app)
      .post("/auth/code/redeem")
      .send({ shortCode: issueRes.body.shortCode });

    expect(redeemRes.status).toBe(410);
  });

  it("rejects an unknown shortCode with 404", async () => {
    const res = await request(app)
      .post("/auth/code/redeem")
      .send({ shortCode: "000001" });

    // 희박하지만 다른 테스트가 발급한 활성 코드와 우연히 일치할 수 있으므로
    // 404 또는(이미 사용됨/만료) 409/410 모두 "존재는 했었다"는 뜻이라 배제하지
    // 않되, 보통은 404가 와야 한다.
    expect([404, 409, 410]).toContain(res.status);
  });

  it("redeems an active shortCode even when a past used-up row shares the same code", async () => {
    // qr_login_tokens.short_code has only a PARTIAL unique index
    // (used_at is null and short_code is not null) — see
    // supabase/migrations/20261022050000_add_qr_short_code.sql. Rows that
    // have already been redeemed (used_at set) are free to share the same
    // short_code with other used rows AND with a newly issued active row.
    // Simulate that by inserting an already-used row with a fixed code,
    // then issuing a fresh token and forcing it to collide with that same
    // code. Looking up by short_code must still find the active row and
    // redeem it successfully instead of erroring out because more than one
    // row matched.
    const { parent, kidMemberId } = await createFamilyWithKid();
    const admin = adminClient();
    const sharedCode = "424242";

    // qr_login_tokens never gets cleaned up, so a previous (e.g. pre-fix,
    // failed) run of this test may have left a still-active row behind
    // with this exact short_code. Clear any leftovers first so this test
    // is self-contained and re-runnable.
    const { error: cleanupError } = await admin
      .from("qr_login_tokens")
      .delete()
      .eq("short_code", sharedCode);
    if (cleanupError) throw cleanupError;

    const { data: family } = await admin
      .from("members")
      .select("family_id")
      .eq("id", kidMemberId)
      .single();

    const { error: usedInsertError } = await admin.from("qr_login_tokens").insert({
      family_id: family!.family_id,
      kid_member_id: kidMemberId,
      issued_by: kidMemberId,
      token: `used-token-${Date.now()}`,
      short_code: sharedCode,
      expires_at: new Date(Date.now() + 60 * 1000).toISOString(),
      used_at: new Date(Date.now() - 60 * 1000).toISOString(),
    });
    if (usedInsertError) throw usedInsertError;

    const issueRes = await request(app)
      .post("/auth/qr/issue")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ kidMemberId });
    expect(issueRes.status).toBe(201);

    // Force the freshly issued active row to use the same short_code as the
    // already-used row above. This is only possible because the unique
    // index is partial (used_at is null) — the used row doesn't conflict.
    const { error: updateError } = await admin
      .from("qr_login_tokens")
      .update({ short_code: sharedCode })
      .eq("token", issueRes.body.token);
    if (updateError) throw updateError;

    const redeemRes = await request(app)
      .post("/auth/code/redeem")
      .send({ shortCode: sharedCode });

    expect(redeemRes.status).toBe(200);
    expect(redeemRes.body.accessToken).toBeDefined();
  });

  it("applies rate limiting to /auth/code/redeem", async () => {
    const res = await request(app)
      .post("/auth/code/redeem")
      .send({ shortCode: "000002" });

    expect(res.headers["ratelimit-limit"]).toBeDefined();
    expect(res.headers["ratelimit-remaining"]).toBeDefined();
  });
});
