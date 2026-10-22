import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import QRCode from "qrcode";
import {
  ActivityIndicator,
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { colors } from "../../lib/theme";
import { formatCountdown, remainingSeconds } from "../../lib/qrCountdown";
import { ApiError } from "../../services/api";
import { issueQrToken } from "../../services/qrAuth";

export default function QrIssueScreen() {
  const { kidMemberId } = useLocalSearchParams<{ kidMemberId: string }>();
  const router = useRouter();

  const [qrDataUrl, setQrDataUrl] = useState<string | null>(null);
  const [secondsLeft, setSecondsLeft] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const expiresAtRef = useRef<string | null>(null);

  const issue = useCallback(async () => {
    setError(null);
    setLoading(true);
    setQrDataUrl(null);
    try {
      const result = await issueQrToken(kidMemberId);
      expiresAtRef.current = result.expiresAt;
      setSecondsLeft(remainingSeconds(result.expiresAt, new Date()));
      const dataUrl = await QRCode.toDataURL(result.token, {
        width: 280,
        margin: 2,
      });
      setQrDataUrl(dataUrl);
    } catch (e) {
      setError(
        e instanceof ApiError ? e.message : "QR 코드를 만들지 못했어요"
      );
    } finally {
      setLoading(false);
    }
  }, [kidMemberId]);

  useEffect(() => {
    issue();
  }, [issue]);

  useEffect(() => {
    if (!expiresAtRef.current || !qrDataUrl) {
      return;
    }
    const interval = setInterval(() => {
      const left = remainingSeconds(expiresAtRef.current!, new Date());
      setSecondsLeft(left);
      if (left <= 0) {
        clearInterval(interval);
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [qrDataUrl]);

  const expired = qrDataUrl !== null && secondsLeft <= 0;

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ headerShown: false }} />

      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backButtonText}>{"<"}</Text>
        </Pressable>
        <Text style={styles.headerTitle}>QR로 로그인 연결하기</Text>
      </View>

      <Text style={styles.instruction}>
        이 화면을 아이 기기 카메라에 보여주세요.{"\n"}2분 안에 스캔해야 해요.
      </Text>

      <View style={styles.qrBox}>
        {loading ? (
          <ActivityIndicator color={colors.accent} />
        ) : error ? (
          <Text style={styles.error}>{error}</Text>
        ) : expired ? (
          <Text style={styles.expiredText}>⏰ 시간이 지났어요</Text>
        ) : qrDataUrl ? (
          <Image
            source={{ uri: qrDataUrl }}
            style={styles.qrImage}
            accessibilityLabel="아이 기기 로그인용 QR 코드"
          />
        ) : null}
      </View>

      {!loading && !error && qrDataUrl && (
        <Text style={expired ? styles.expiredTimer : styles.timer}>
          {expired ? "다시 만들어주세요" : `남은 시간 ${formatCountdown(secondsLeft)}`}
        </Text>
      )}

      {(expired || error) && (
        <Pressable style={styles.button} onPress={issue}>
          <Text style={styles.buttonText}>새로 QR 만들기</Text>
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.pageBackground,
    padding: 24,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 16,
  },
  backButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.card,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 10,
  },
  backButtonText: {
    fontSize: 18,
    fontWeight: "700",
    color: colors.textPrimary,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: "800",
    color: colors.textPrimary,
  },
  instruction: {
    fontSize: 14,
    color: colors.bannerText,
    backgroundColor: colors.bannerBackground,
    borderRadius: 12,
    padding: 14,
    lineHeight: 20,
    marginBottom: 20,
  },
  qrBox: {
    backgroundColor: colors.card,
    borderRadius: 18,
    padding: 24,
    alignItems: "center",
    justifyContent: "center",
    minHeight: 320,
  },
  qrImage: {
    width: 280,
    height: 280,
  },
  error: {
    color: colors.danger,
    fontSize: 14,
    textAlign: "center",
  },
  expiredText: {
    fontSize: 20,
    fontWeight: "700",
    color: colors.textSecondary,
  },
  timer: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
    textAlign: "center",
    marginTop: 16,
  },
  expiredTimer: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.danger,
    textAlign: "center",
    marginTop: 16,
  },
  button: {
    backgroundColor: colors.accent,
    borderRadius: 999,
    paddingVertical: 14,
    alignItems: "center",
    marginTop: 20,
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "700",
  },
});
