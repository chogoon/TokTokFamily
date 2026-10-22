import { Stack } from "expo-router";
import { AuthProvider } from "../contexts/AuthContext";
import { configureNotificationHandler } from "../lib/pushNotifications";

configureNotificationHandler();

export default function RootLayout() {
  return (
    <AuthProvider>
      <Stack />
    </AuthProvider>
  );
}
