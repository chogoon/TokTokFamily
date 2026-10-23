import { useRouter } from "expo-router";
import { useCallback, useRef, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useAuth } from "../../contexts/AuthContext";
import { isCompleteShortCode, sanitizeShortCodeInput } from "../../lib/shortCode";
import { colors } from "../../lib/theme";
import { ApiError } from "../../services/api";
import { redeemShortCode } from "../../services/qrAuth";

export default function EnterCodeScreen() {
  const router = useRouter();
  const { refreshMember } = useAuth();
  const [code, setCode] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const handledRef = useRef(false);

  const submit = useCallback(
    async (value: string) => {
      if (handledRef.current || !isCompleteShortCode(value)) {
        return;
      }
      handledRef.current = true;
      setStatus("loading");
      setErrorMessage(null);

      try {
        await redeemShortCode(value);
        await refreshMember();
        router.replace("/(tabs)");
      } catch (e) {
        if (e instanceof ApiError) {
          if (e.status === 404) setErrorMessage("코드를 찾을 수 없어요");
          else if (e.status === 409) setErrorMessage("이미 사용한 코드예요");
          else if (e.status === 410) setErrorMessage("코드 시간이 지났어요");
          else if (e.status === 429)
            setErrorMessage("너무 많이 시도했어요, 잠시 후 다시 해주세요");
          else setErrorMessage("로그인하지 못했어요");
        } else {
          setErrorMessage("로그인하지 못했어요");
        }
        setStatus("error");
      }
    },
    [refreshMember, router]
  );

  const handleChangeText = useCallback(
    (text: string) => {
      const sanitized = sanitizeShortCodeInput(text);
      setCode(sanitized);
      if (isCompleteShortCode(sanitized)) {
        submit(sanitized);
      }
    },
    [submit]
  );

  const handleRetry = useCallback(() => {
    handledRef.current = false;
    setErrorMessage(null);
    setCode("");
    setStatus("idle");
  }, []);

  return (
    <View style={styles.container}>
      {status !== "error" && (
        <>
          <Text style={styles.emoji}>🔢</Text>
          <Text style={styles.title}>번호로 로그인해요</Text>
          <Text style={styles.subtitle}>
            부모님 화면에 보이는 6자리 번호를 입력해주세요
          </Text>

          <TextInput
            style={styles.input}
            value={code}
            onChangeText={handleChangeText}
            keyboardType="number-pad"
            maxLength={6}
            autoFocus
            editable={status !== "loading"}
            placeholder="482913"
            placeholderTextColor={colors.textSecondary}
          />

          {status === "loading" && (
            <ActivityIndicator color={colors.accent} style={styles.spinner} />
          )}

          <Pressable
            style={styles.linkButton}
            onPress={() => router.replace("/(auth)/scan-qr")}
          >
            <Text style={styles.linkButtonText}>📷 QR로 스캔하기</Text>
          </Pressable>
        </>
      )}

      {status === "error" && (
        <View style={styles.overlay}>
          <Text style={styles.emoji}>😢</Text>
          <Text style={styles.title}>{errorMessage}</Text>
          <Pressable style={styles.button} onPress={handleRetry}>
            <Text style={styles.buttonText}>다시 입력하기</Text>
          </Pressable>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.pageBackground,
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
  },
  overlay: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
  },
  emoji: {
    fontSize: 48,
    marginBottom: 12,
  },
  title: {
    fontSize: 18,
    fontWeight: "800",
    color: colors.textPrimary,
    textAlign: "center",
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    color: colors.textSecondary,
    textAlign: "center",
    marginBottom: 20,
    lineHeight: 20,
  },
  input: {
    backgroundColor: "#FFFFFF",
    borderRadius: 999,
    borderWidth: 2,
    borderColor: colors.border,
    paddingHorizontal: 24,
    paddingVertical: 16,
    fontSize: 28,
    fontWeight: "800",
    letterSpacing: 6,
    textAlign: "center",
    color: colors.textPrimary,
    minWidth: 240,
  },
  spinner: {
    marginTop: 16,
  },
  linkButton: {
    alignItems: "center",
    paddingVertical: 14,
    marginTop: 16,
  },
  linkButtonText: {
    fontSize: 14,
    fontWeight: "700",
    color: colors.kid,
  },
  button: {
    backgroundColor: colors.accent,
    borderRadius: 999,
    paddingVertical: 14,
    paddingHorizontal: 32,
    alignItems: "center",
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "700",
  },
});
