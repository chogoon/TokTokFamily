import { describe, expect, it, vi, beforeEach } from "vitest";

const { sendExpoPushNotificationsMock, sendFcmPushNotificationsMock } = vi.hoisted(() => ({
  sendExpoPushNotificationsMock: vi.fn().mockResolvedValue(undefined),
  sendFcmPushNotificationsMock: vi.fn().mockResolvedValue(undefined),
}));

vi.mock("./expoPush", () => ({
  sendExpoPushNotifications: sendExpoPushNotificationsMock,
}));

vi.mock("./firebaseAdminPush", () => ({
  sendFcmPushNotifications: sendFcmPushNotificationsMock,
}));

import { dispatchPushNotifications } from "./pushDispatch";
import type { PushTarget } from "./pushRecipients";

describe("dispatchPushNotifications", () => {
  beforeEach(() => {
    sendExpoPushNotificationsMock.mockClear();
    sendFcmPushNotificationsMock.mockClear();
  });

  it("routes expo and fcm targets to their respective senders when both are present", async () => {
    const targets: PushTarget[] = [
      { pushToken: "ExponentPushToken[a]", provider: "expo" },
      { pushToken: "fcm-token-b", provider: "fcm" },
    ];

    await dispatchPushNotifications(targets, { title: "제목", body: "내용" });

    expect(sendExpoPushNotificationsMock).toHaveBeenCalledTimes(1);
    expect(sendExpoPushNotificationsMock).toHaveBeenCalledWith([
      { to: "ExponentPushToken[a]", title: "제목", body: "내용" },
    ]);

    expect(sendFcmPushNotificationsMock).toHaveBeenCalledTimes(1);
    expect(sendFcmPushNotificationsMock).toHaveBeenCalledWith([
      { token: "fcm-token-b", title: "제목", body: "내용" },
    ]);
  });

  it("only calls the expo sender when all targets are expo", async () => {
    const targets: PushTarget[] = [
      { pushToken: "ExponentPushToken[a]", provider: "expo" },
      { pushToken: "ExponentPushToken[b]", provider: "expo" },
    ];

    await dispatchPushNotifications(targets, { title: "제목", body: "내용" });

    expect(sendExpoPushNotificationsMock).toHaveBeenCalledTimes(1);
    expect(sendFcmPushNotificationsMock).not.toHaveBeenCalled();
  });

  it("only calls the fcm sender when all targets are fcm", async () => {
    const targets: PushTarget[] = [
      { pushToken: "fcm-token-a", provider: "fcm" },
      { pushToken: "fcm-token-b", provider: "fcm" },
    ];

    await dispatchPushNotifications(targets, { title: "제목", body: "내용" });

    expect(sendFcmPushNotificationsMock).toHaveBeenCalledTimes(1);
    expect(sendExpoPushNotificationsMock).not.toHaveBeenCalled();
  });

  it("calls neither sender when there are no targets", async () => {
    await dispatchPushNotifications([], { title: "제목", body: "내용" });

    expect(sendExpoPushNotificationsMock).not.toHaveBeenCalled();
    expect(sendFcmPushNotificationsMock).not.toHaveBeenCalled();
  });
});
