import { useRouter } from "expo-router";
import { useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useAuth } from "../../contexts/AuthContext";
import { colors } from "../../lib/theme";
import { ApiError } from "../../services/api";
import { redeemInvite } from "../../services/families";

export default function JoinFamilyScreen() {
  const router = useRouter();
  const { refreshMember } = useAuth();
  const [code, setCode] = useState("");
  const [parentName, setParentName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleJoin() {
    setError(null);
    setLoading(true);
    try {
      await redeemInvite(code.trim().toUpperCase(), parentName.trim());
      await refreshMember();
      router.replace("/(tabs)");
    } catch (e) {
      if (e instanceof ApiError) {
        if (e.status === 404) setError("초대 코드를 찾을 수 없어요");
        else if (e.status === 409) setError("이미 사용된 초대 코드예요");
        else if (e.status === 410) setError("초대 코드가 만료됐어요");
        else setError(e.message);
      } else {
        setError("가족에 참여하지 못했어요");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>초대 코드로 참여하기</Text>
      <Text style={styles.subtitle}>
        다른 보호자님께 받은 초대 코드와 보호자님 이름을 입력해주세요
      </Text>

      <TextInput
        style={[styles.input, styles.codeInput]}
        placeholder="초대 코드"
        autoCapitalize="characters"
        maxLength={8}
        value={code}
        onChangeText={setCode}
      />
      <TextInput
        style={styles.input}
        placeholder="보호자님 이름"
        value={parentName}
        onChangeText={setParentName}
      />

      {error && <Text style={styles.error}>{error}</Text>}

      <Pressable
        style={[styles.button, loading && styles.buttonDisabled]}
        onPress={handleJoin}
        disabled={loading || !code.trim() || !parentName.trim()}
      >
        {loading ? (
          <ActivityIndicator color="#FFFFFF" />
        ) : (
          <Text style={styles.buttonText}>참여하기</Text>
        )}
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
    color: colors.textPrimary,
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: colors.textSecondary,
    marginBottom: 24,
    lineHeight: 20,
  },
  input: {
    backgroundColor: "#FFFFFF",
    borderRadius: 999,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 15,
    borderWidth: 2,
    borderColor: colors.border,
    marginBottom: 12,
  },
  codeInput: {
    textAlign: "center",
    fontSize: 20,
    fontWeight: "700",
    letterSpacing: 4,
  },
  error: {
    color: colors.danger,
    fontSize: 13,
    marginBottom: 12,
  },
  button: {
    backgroundColor: colors.accent,
    borderRadius: 999,
    paddingVertical: 14,
    alignItems: "center",
    marginTop: 8,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "700",
  },
});
