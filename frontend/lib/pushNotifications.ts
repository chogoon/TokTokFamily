import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

// 네이티브 API(getExpoPushTokenAsync 등)를 직접 호출하는 부분과, 순수 로직(플랫폼 문자열 매핑)을
// 분리한다. 순수 로직은 pushNotifications.test.ts에서 네트워크/네이티브 모듈 없이 테스트한다
// (frontend/CLAUDE.md 방침 — Jest는 네이티브 모듈 모킹 없이 순수 로직만 검증).

export type DevicePlatform = "ios" | "android";

/**
 * React Native의 Platform.OS를 devices 테이블의 platform 컬럼 값으로 매핑한다.
 * web 등 지원하지 않는 플랫폼이면 null (devices 테이블 check 제약은 ios/android만 허용한다).
 */
export function getPlatform(osName: string): DevicePlatform | null {
  if (osName === "ios" || osName === "android") {
    return osName;
  }
  return null;
}

/** 앱 전역에서 한 번 호출해, 포그라운드에서도 알림 배너가 보이도록 핸들러를 설정한다. */
export function configureNotificationHandler(): void {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldPlaySound: false,
      shouldSetBadge: false,
    }),
  });
}

/**
 * 알림 권한을 확인/요청하고, 허용되면 Expo 푸시 토큰을 받아 반환한다.
 * 시뮬레이터/웹이거나 권한이 거부되거나 토큰 발급이 실패하면 null을 반환한다(throw하지 않음 —
 * 알림은 선택 기능이라 실패가 로그인/앱 사용을 막으면 안 된다).
 */
export async function registerForPushNotificationsAsync(): Promise<string | null> {
  if (!Device.isDevice) {
    return null;
  }

  const platform = getPlatform(Platform.OS);
  if (!platform) {
    return null;
  }

  try {
    if (platform === "android") {
      await Notifications.setNotificationChannelAsync("default", {
        name: "default",
        importance: Notifications.AndroidImportance.DEFAULT,
      });
    }

    const existing = await Notifications.getPermissionsAsync();
    let finalStatus = existing.status;

    if (finalStatus !== "granted") {
      const requested = await Notifications.requestPermissionsAsync();
      finalStatus = requested.status;
    }

    if (finalStatus !== "granted") {
      return null;
    }

    const tokenResponse = await Notifications.getExpoPushTokenAsync();
    return tokenResponse.data;
  } catch {
    return null;
  }
}
