import request from "supertest";
import { describe, expect, it, vi, beforeEach } from "vitest";
import { createApp } from "../app";
import "../test/supabaseTestEnv";

vi.mock("../lib/pushRecipients", () => ({
  recipientsForMessage: vi
    .fn()
    .mockResolvedValue([{ pushToken: "ExponentPushToken[fake]", provider: "expo" }]),
  recipientsForPraise: vi.fn().mockResolvedValue([]),
}));

vi.mock("../lib/pushDispatch", () => ({
  dispatchPushNotifications: vi.fn().mockResolvedValue(undefined),
}));

const app = createApp();

describe("POST /webhooks/push", () => {
  beforeEach(() => {
    process.env.PUSH_WEBHOOK_SECRET = "test-secret";
  });

  it("rejects requests without the correct webhook secret", async () => {
    const res = await request(app)
      .post("/webhooks/push")
      .send({ type: "INSERT", table: "messages", record: {} });

    expect(res.status).toBe(401);
  });

  it("accepts a valid messages INSERT webhook", async () => {
    const res = await request(app)
      .post("/webhooks/push")
      .set("x-webhook-secret", "test-secret")
      .send({
        type: "INSERT",
        table: "messages",
        record: { room_id: "r1", sender_id: "s1", is_urgent: false, body: "hi" },
      });

    expect(res.status).toBe(200);
  });

  it("skips non-INSERT events", async () => {
    const res = await request(app)
      .post("/webhooks/push")
      .set("x-webhook-secret", "test-secret")
      .send({ type: "UPDATE", table: "messages", record: {} });

    expect(res.status).toBe(200);
    expect(res.body.skipped).toBe(true);
  });
});
