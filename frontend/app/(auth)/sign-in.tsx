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
import { supabase } from "../../services/supabase";
import { colors } from "../../lib/theme";
import { mapSignInErrorMessage } from "../../lib/authErrors";

export default function SignInScreen() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSignIn() {
    setError(null);
    setLoading(true);
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    setLoading(false);

    if (signInError) {
      setError(mapSignInErrorMessage(signInError.message));
      return;
    }

    router.replace("/");
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>
        우리가족<Text style={{ color: colors.kid }}>톡톡</Text>
      </Text>
      <Text style={styles.subtitle}>보호자 계정으로 로그인해요</Text>

      <TextInput
        style={styles.input}
        placeholder="이메일"
        autoCapitalize="none"
        keyboardType="email-address"
        value={email}
        onChangeText={setEmail}
      />
      <TextInput
        style={styles.input}
        placeholder="비밀번호"
        secureTextEntry
        value={password}
        onChangeText={setPassword}
      />

      {error && <Text style={styles.error}>{error}</Text>}

      <Pressable
        style={[styles.button, loading && styles.buttonDisabled]}
        onPress={handleSignIn}
        disabled={loading}
      >
        {loading ? (
          <ActivityIndicator color="#FFFFFF" />
        ) : (
          <Text style={styles.buttonText}>로그인</Text>
        )}
      </Pressable>

      <Pressable
        style={styles.secondaryLink}
        onPress={() => router.push("/(auth)/sign-up")}
      >
        <Text style={styles.secondaryLinkText}>
          계정이 없으신가요? 가입하기
        </Text>
      </Pressable>

      <Pressable
        style={styles.kidLink}
        onPress={() => router.push("/(auth)/scan-qr")}
      >
        <Text style={styles.kidLinkText}>
          🙂 아이인가요? QR로 로그인하기
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
  secondaryLink: {
    alignItems: "center",
    paddingVertical: 14,
    marginTop: 8,
  },
  secondaryLinkText: {
    fontSize: 14,
    fontWeight: "700",
    color: colors.textSecondary,
  },
  kidLink: {
    alignItems: "center",
    paddingVertical: 14,
  },
  kidLinkText: {
    fontSize: 14,
    fontWeight: "700",
    color: colors.kid,
  },
});
