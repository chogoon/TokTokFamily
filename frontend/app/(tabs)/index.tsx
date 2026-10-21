import { StyleSheet, Text, View } from "react-native";
import { useAuth } from "../../contexts/AuthContext";
import { colors } from "../../lib/theme";

export default function HomeScreen() {
  const { member } = useAuth();

  return (
    <View style={styles.container}>
      <Text style={styles.title}>
        우리가족<Text style={{ color: colors.kid }}>톡톡</Text>
      </Text>
      <Text style={styles.subtitle}>
        {member ? `${member.name}님, 안녕하세요` : "불러오는 중..."}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.pageBackground,
    padding: 24,
  },
  title: {
    fontSize: 22,
    fontWeight: "800",
    letterSpacing: -0.5,
    color: colors.textPrimary,
    marginTop: 12,
  },
  subtitle: {
    fontSize: 14,
    color: colors.textSecondary,
    marginTop: 8,
  },
});
