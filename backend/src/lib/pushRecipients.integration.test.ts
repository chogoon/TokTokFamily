import { beforeAll, describe, expect, it } from "vitest";
import { recipientsForMessage, recipientsForPraise } from "./pushRecipients";
import { isLocalSupabaseUp } from "../test/supabaseTestEnv";
import { adminClient, createAuthedUser } from "../test/testHelpers";

async function createFamilyWithParentAndKid() {
  const admin = adminClient();
  const parent = await createAuthedUser();

  const { data: family } = await admin
    .from("families")
    .insert({ name: "Push Test Family" })
    .select("id")
    .single();

  const { data: parentMember } = await admin
    .from("members")
    .insert({ family_id: family!.id, role: "parent", name: "Parent", auth_user_id: parent.authUserId })
    .select("id")
    .single();

  const { data: kidMember } = await admin
    .from("members")
    .insert({ family_id: family!.id, role: "kid", name: "Kid" })
    .select("id")
    .single();

  await admin.from("devices").insert([
    {
      member_id: parentMember!.id,
      push_token: "ExponentPushToken[parent-token]",
      platform: "ios",
      provider: "expo",
    },
    {
      member_id: kidMember!.id,
      push_token: "ExponentPushToken[kid-token]",
      platform: "android",
      provider: "expo",
    },
  ]);

  return { familyId: family!.id, parentMemberId: parentMember!.id as string, kidMemberId: kidMember!.id as string };
}

describe("pushRecipients (requires local Supabase)", () => {
  beforeAll(async () => {
    const up = await isLocalSupabaseUp();
    if (!up) {
      throw new Error(
        "local Supabase is not running — run `npx supabase start` before `npm test`"
      );
    }
  });

  it("finds the parent as recipient for a kid-room message sent by the kid", async () => {
    const { familyId, parentMemberId, kidMemberId } = await createFamilyWithParentAndKid();
    const admin = adminClient();

    const { data: room } = await admin
      .from("rooms")
      .insert({ family_id: familyId, type: "kid", kid_member_id: kidMemberId })
      .select("id")
      .single();

    const targets = await recipientsForMessage(admin, room!.id, kidMemberId);

    expect(targets).toHaveLength(1);
    expect(targets[0].pushToken).toBe("ExponentPushToken[parent-token]");
    expect(parentMemberId).toBeDefined();
  });

  it("excludes the sender from family-room message recipients", async () => {
    const { familyId, kidMemberId } = await createFamilyWithParentAndKid();
    const admin = adminClient();

    const { data: room } = await admin
      .from("rooms")
      .insert({ family_id: familyId, type: "family" })
      .select("id")
      .single();

    const targets = await recipientsForMessage(admin, room!.id, kidMemberId);

    expect(targets).toHaveLength(1);
    expect(targets[0].pushToken).toBe("ExponentPushToken[parent-token]");
  });

  it("finds the kid as recipient for a new praise on their board", async () => {
    const { familyId, kidMemberId } = await createFamilyWithParentAndKid();
    const admin = adminClient();

    const { data: board } = await admin
      .from("praise_boards")
      .insert({ family_id: familyId, kid_member_id: kidMemberId, goal_text: "목표" })
      .select("id")
      .single();

    const targets = await recipientsForPraise(admin, board!.id);

    expect(targets).toHaveLength(1);
    expect(targets[0].pushToken).toBe("ExponentPushToken[kid-token]");
  });
});
