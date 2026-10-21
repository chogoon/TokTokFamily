import request from "supertest";
import { beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../app";
import { isLocalSupabaseUp } from "../test/supabaseTestEnv";
import { adminClient, createAuthedUser } from "../test/testHelpers";

const app = createApp();

describe("families routes (requires local Supabase)", () => {
  beforeAll(async () => {
    const up = await isLocalSupabaseUp();
    if (!up) {
      throw new Error(
        "local Supabase is not running — run `npx supabase start` before `npm test`"
      );
    }
  });

  it("creates a family and bootstraps the caller as parent", async () => {
    const { accessToken } = await createAuthedUser();

    const res = await request(app)
      .post("/families")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ familyName: "Test Family", parentName: "Test Parent" });

    expect(res.status).toBe(201);
    expect(res.body.familyId).toBeDefined();
    expect(res.body.memberId).toBeDefined();
  });

  it("rejects creating a second family for the same user", async () => {
    const { accessToken } = await createAuthedUser();

    await request(app)
      .post("/families")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ familyName: "First Family", parentName: "Parent" });

    const res = await request(app)
      .post("/families")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ familyName: "Second Family", parentName: "Parent" });

    expect(res.status).toBe(409);
  });

  it("rejects requests without a bearer token", async () => {
    const res = await request(app)
      .post("/families")
      .send({ familyName: "No Auth", parentName: "Nobody" });

    expect(res.status).toBe(401);
  });

  it("lets a parent issue an invite, and a second user redeem it", async () => {
    const parent = await createAuthedUser();
    await request(app)
      .post("/families")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ familyName: "Invite Family", parentName: "Parent One" });

    const inviteRes = await request(app)
      .post("/families/invites")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({});

    expect(inviteRes.status).toBe(201);
    expect(inviteRes.body.code).toBeDefined();

    const secondParent = await createAuthedUser();
    const redeemRes = await request(app)
      .post("/families/invites/redeem")
      .set("Authorization", `Bearer ${secondParent.accessToken}`)
      .send({ code: inviteRes.body.code, parentName: "Parent Two" });

    expect(redeemRes.status).toBe(200);
    expect(redeemRes.body.familyId).toBeDefined();
  });

  it("rejects a kid from issuing invites", async () => {
    const parent = await createAuthedUser();
    const familyRes = await request(app)
      .post("/families")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ familyName: "Kid Family", parentName: "Parent" });

    const admin = adminClient();
    const kidAuth = await createAuthedUser();
    await admin.from("members").insert({
      family_id: familyRes.body.familyId,
      role: "kid",
      name: "Kid",
      auth_user_id: kidAuth.authUserId,
    });

    const res = await request(app)
      .post("/families/invites")
      .set("Authorization", `Bearer ${kidAuth.accessToken}`)
      .send({});

    expect(res.status).toBe(403);
  });

  it("rejects an expired or already-used invite code", async () => {
    const res = await request(app)
      .post("/families/invites/redeem")
      .set("Authorization", `Bearer ${(await createAuthedUser()).accessToken}`)
      .send({ code: "DOESNOTEXIST", parentName: "Nobody" });

    expect(res.status).toBe(404);
  });
});
