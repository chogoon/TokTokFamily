import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getMessaging, type TokenMessage } from "firebase-admin/messaging";

export interface FcmPushMessage {
  token: string;
  title: string;
  body: string;
}

let app: App | undefined;

/**
 * Firebase Admin 앱을 모듈 로드 시점이 아니라 호출 시점에 1회만 초기화한다
 * (singleton 패턴, `supabaseAdmin.ts`와 동일). FCM을 쓰지 않는 로컬 개발
 * 환경(RN만 쓰는 중)에서는 FIREBASE_SERVICE_ACCOUNT_KEY가 없어도 앱이
 * 크래시하지 않고, 이 함수가 실제로 호출될 때만 에러를 던진다.
 */
function getFirebaseAdminApp(): App {
  if (app) {
    return app;
  }

  if (getApps().length > 0) {
    app = getApps()[0];
    return app;
  }

  const serviceAccountKeyJson = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (!serviceAccountKeyJson) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_KEY must be set to send FCM push notifications"
    );
  }

  const serviceAccount = JSON.parse(serviceAccountKeyJson);
  app = initializeApp({ credential: cert(serviceAccount) });
  return app;
}

/**
 * FCM 네이티브 토큰(Flutter 클라이언트)으로 푸시를 발송한다.
 *
 * Expo 쪽(`sendExpoPushNotifications`)은 발송 전에 `Expo.isExpoPushToken`으로
 * 토큰 형식을 사전 검증하지만, FCM에는 그런 사전 검증 유틸이 없다. 대신
 * `sendEach`의 결과(`BatchResponse.responses[].success`)를 보고 실패한 건만
 * 로그로 남기고, 개별 실패가 다른 메시지 발송이나 전체 흐름을 막지 않게 한다.
 */
export async function sendFcmPushNotifications(
  messages: FcmPushMessage[]
): Promise<void> {
  if (messages.length === 0) {
    return;
  }

  const firebaseApp = getFirebaseAdminApp();

  const tokenMessages: TokenMessage[] = messages.map((m) => ({
    token: m.token,
    notification: { title: m.title, body: m.body },
  }));

  const response = await getMessaging(firebaseApp).sendEach(tokenMessages);

  response.responses.forEach((result, index) => {
    if (!result.success) {
      // eslint-disable-next-line no-console
      console.error(
        `[fcmPush] failed to send to token ending in ...${messages[index].token.slice(-6)}:`,
        result.error
      );
    }
  });
}
