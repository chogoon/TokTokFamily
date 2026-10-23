import { sendExpoPushNotifications } from "./expoPush";
import { sendFcmPushNotifications } from "./firebaseAdminPush";
import type { PushTarget } from "./pushRecipients";

export interface PushContent {
  title: string;
  body: string;
}

/**
 * provider(expo/fcm)별로 타겟을 그룹화해 각자 맞는 발송 함수로 라우팅한다.
 * RN(Expo) 클라이언트와 Flutter(FCM) 클라이언트가 공존하는 동안 이 함수가
 * `pushWebhook.ts`의 유일한 발송 진입점이 된다.
 */
export async function dispatchPushNotifications(
  targets: PushTarget[],
  content: PushContent
): Promise<void> {
  const expoTargets = targets.filter((t) => t.provider === "expo");
  const fcmTargets = targets.filter((t) => t.provider === "fcm");

  await Promise.all([
    expoTargets.length > 0
      ? sendExpoPushNotifications(
          expoTargets.map((t) => ({
            to: t.pushToken,
            title: content.title,
            body: content.body,
          }))
        )
      : Promise.resolve(),
    fcmTargets.length > 0
      ? sendFcmPushNotifications(
          fcmTargets.map((t) => ({
            token: t.pushToken,
            title: content.title,
            body: content.body,
          }))
        )
      : Promise.resolve(),
  ]);
}
