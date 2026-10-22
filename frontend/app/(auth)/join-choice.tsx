import { useRouter } from "expo-router";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { colors } from "../../lib/theme";

export default function JoinChoiceScreen() {
  const router = useRouter();

  return (
    <View style={styles.container}>
      <Text style={styles.title}>
        우리가족<Text style={{ color: colors.kid }}>톡톡</Text>
      </Text>
      <Text style={styles.subtitle}>어떻게 시작할까요?</Text>

      <Pressable
        style={styles.card}
        onPress={() => router.push("/(auth)/create-family")}
      >
        <Text style={styles.cardEmoji}>👪</Text>
        <Text style={styles.cardTitle}>새 가족 만들기</Text>
        <Text style={styles.cardDesc}>
          우리 가족이 처음 쓰는 경우예요. 가족 이름을 정하고 시작해요.
        </Text>
      </Pressable>

      <Pressable
        style={styles.card}
        onPress={() => router.push("/(auth)/join-family")}
      >
        <Text style={styles.cardEmoji}>🔗</Text>
        <Text style={styles.cardTitle}>초대 코드로 참여하기</Text>
        <Text style={styles.cardDesc}>
          다른 보호자님이 만든 가족에 초대 코드로 들어가요.
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.pageBackground,
    padding: 24,
    justifyContent: "center",
  },
  title: {
    fontSize: 22,
    fontWeight: "800",
    letterSpacing: -0.5,
    color: colors.textPrimary,
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: colors.textSecondary,
    marginBottom: 24,
  },
  card: {
    backgroundColor: colors.card,
    borderRadius: 18,
    padding: 18,
    marginBottom: 12,
    borderWidth: 2,
    borderColor: colors.border,
  },
  cardEmoji: {
    fontSize: 28,
    marginBottom: 8,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
    marginBottom: 4,
  },
  cardDesc: {
    fontSize: 13,
    color: colors.textSecondary,
    lineHeight: 18,
  },
});
