import { Redirect } from "expo-router";
import { ActivityIndicator, View } from "react-native";
import { useAuth } from "../contexts/AuthContext";
import { colors } from "../lib/theme";

export default function Index() {
  const { session, member, loading } = useAuth();

  if (loading) {
    return (
      <View style={{ flex: 1, backgroundColor: colors.pageBackground, justifyContent: "center" }}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  if (!session) {
    return <Redirect href="/(auth)/sign-up" />;
  }

  if (!member) {
    return <Redirect href="/(auth)/create-family" />;
  }

  return <Redirect href="/(tabs)" />;
}
