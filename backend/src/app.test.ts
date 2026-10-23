import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp } from "./app";

describe("CORS", () => {
  it("allows cross-origin preflight requests (Expo web dev server)", async () => {
    const app = createApp();

    const res = await request(app)
      .options("/families")
      .set("Origin", "http://localhost:8081")
      .set("Access-Control-Request-Method", "POST");

    expect(res.headers["access-control-allow-origin"]).toBeDefined();
  });
});
