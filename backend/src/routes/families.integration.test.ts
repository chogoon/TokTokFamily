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

  it("lets a parent add a kid, creating a family room (once), a kid room, and a praise board", async () => {
    const parent = await createAuthedUser();
    const familyRes = await request(app)
      .post("/families")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ familyName: "Add Kid Family", parentName: "Parent" });

    const kidRes = await request(app)
      .post("/families/kids")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ name: "서아", avatar: "🐣", color: "#FFB547" });

    expect(kidRes.status).toBe(201);
    expect(kidRes.body.memberId).toBeDefined();
    expect(kidRes.body.kidRoomId).toBeDefined();

    const admin = adminClient();
    const { data: board } = await admin
      .from("praise_boards")
      .select("kid_member_id")
      .eq("kid_member_id", kidRes.body.memberId)
      .maybeSingle();
    expect(board).not.toBeNull();

    await request(app)
      .post("/families/kids")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ name: "하늘", avatar: "🦖", color: "#6BCB77" });

    const { data: familyRooms } = await admin
      .from("rooms")
      .select("id")
      .eq("family_id", familyRes.body.familyId)
      .eq("type", "family");
    expect(familyRooms).toHaveLength(1);
  });

  it("rejects a kid from adding another kid", async () => {
    const parent = await createAuthedUser();
    const familyRes = await request(app)
      .post("/families")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ familyName: "Kid Adds Kid Family", parentName: "Parent" });

    const admin = adminClient();
    const kidAuth = await createAuthedUser();
    await admin.from("members").insert({
      family_id: familyRes.body.familyId,
      role: "kid",
      name: "Kid",
      auth_user_id: kidAuth.authUserId,
    });

    const res = await request(app)
      .post("/families/kids")
      .set("Authorization", `Bearer ${kidAuth.accessToken}`)
      .send({ name: "다른아이", avatar: "🐰", color: "#B28DFF" });

    expect(res.status).toBe(403);
  });

  it("rejects an invalid avatar/color not in the fixed palette", async () => {
    const parent = await createAuthedUser();
    await request(app)
      .post("/families")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ familyName: "Bad Palette Family", parentName: "Parent" });

    const res = await request(app)
      .post("/families/kids")
      .set("Authorization", `Bearer ${parent.accessToken}`)
      .send({ name: "아이", avatar: "🚀", color: "#000000" });

    expect(res.status).toBe(400);
  });
});
