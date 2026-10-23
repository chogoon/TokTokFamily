import { Expo, ExpoPushMessage } from "expo-server-sdk";

const expo = new Expo();

export async function sendExpoPushNotifications(
  messages: ExpoPushMessage[]
): Promise<void> {
  const validMessages = messages.filter((m) =>
    Expo.isExpoPushToken(m.to as string)
  );

  const chunks = expo.chunkPushNotifications(validMessages);
  for (const chunk of chunks) {
    await expo.sendPushNotificationsAsync(chunk);
  }
}
