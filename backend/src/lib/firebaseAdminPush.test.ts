import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const sendEachMock = vi.fn();
const getMessagingMock = vi.fn(() => ({ sendEach: sendEachMock }));
const initializeAppMock = vi.fn(() => ({ name: "fake-app" }));
const certMock = vi.fn((input: unknown) => input);
const getAppsMock = vi.fn(() => []);

vi.mock("firebase-admin/app", () => ({
  initializeApp: initializeAppMock,
  cert: certMock,
  getApps: getAppsMock,
}));

vi.mock("firebase-admin/messaging", () => ({
  getMessaging: getMessagingMock,
}));

describe("sendFcmPushNotifications", () => {
  const originalEnv = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;

  beforeEach(() => {
    vi.resetModules();
    sendEachMock.mockReset();
    getMessagingMock.mockClear();
    initializeAppMock.mockClear();
    certMock.mockClear();
    getAppsMock.mockReturnValue([]);
    process.env.FIREBASE_SERVICE_ACCOUNT_KEY = JSON.stringify({
      project_id: "fake-project",
      client_email: "fake@example.com",
      private_key: "fake-key",
    });
  });

  afterEach(() => {
    process.env.FIREBASE_SERVICE_ACCOUNT_KEY = originalEnv;
  });

  it("sends messages and does not throw when some responses fail", async () => {
    sendEachMock.mockResolvedValue({
      responses: [
        { success: true, messageId: "msg-1" },
        { success: false, error: { code: "messaging/registration-token-not-registered" } },
      ],
      successCount: 1,
      failureCount: 1,
    });

    const { sendFcmPushNotifications } = await import("./firebaseAdminPush");

    await expect(
      sendFcmPushNotifications([
        { token: "valid-token", title: "제목", body: "내용" },
        { token: "invalid-token", title: "제목2", body: "내용2" },
      ])
    ).resolves.toBeUndefined();

    expect(sendEachMock).toHaveBeenCalledTimes(1);
    const sentMessages = sendEachMock.mock.calls[0][0];
    expect(sentMessages).toHaveLength(2);
    expect(sentMessages[0]).toMatchObject({
      token: "valid-token",
      notification: { title: "제목", body: "내용" },
    });
  });

  it("does nothing when given an empty message list", async () => {
    const { sendFcmPushNotifications } = await import("./firebaseAdminPush");

    await sendFcmPushNotifications([]);

    expect(sendEachMock).not.toHaveBeenCalled();
  });

  it("initializes the Firebase Admin app only once across multiple calls", async () => {
    sendEachMock.mockResolvedValue({ responses: [], successCount: 0, failureCount: 0 });

    const { sendFcmPushNotifications } = await import("./firebaseAdminPush");

    await sendFcmPushNotifications([{ token: "t1", title: "a", body: "b" }]);
    await sendFcmPushNotifications([{ token: "t2", title: "a", body: "b" }]);

    expect(initializeAppMock).toHaveBeenCalledTimes(1);
  });

  it("throws a clear error when FIREBASE_SERVICE_ACCOUNT_KEY is not set", async () => {
    delete process.env.FIREBASE_SERVICE_ACCOUNT_KEY;

    const { sendFcmPushNotifications } = await import("./firebaseAdminPush");

    await expect(
      sendFcmPushNotifications([{ token: "t1", title: "a", body: "b" }])
    ).rejects.toThrow(/FIREBASE_SERVICE_ACCOUNT_KEY/);
  });
});
