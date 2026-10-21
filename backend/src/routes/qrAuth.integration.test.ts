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
});
