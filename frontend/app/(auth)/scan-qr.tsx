import { CameraView, useCameraPermissions } from "expo-camera";
import { useRouter } from "expo-router";
import { useCallback, useRef, useState } from "react";
import {
  ActivityIndicator,
  Linking,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { useAuth } from "../../contexts/AuthContext";
import { describeCameraPermissionState } from "../../lib/cameraPermission";
import { colors } from "../../lib/theme";
import { ApiError } from "../../services/api";
import { redeemQrToken } from "../../services/qrAuth";

export default function ScanQrScreen() {
  const router = useRouter();
  const { refreshMember } = useAuth();
  const [permission, requestPermission] = useCameraPermissions();
  const [status, setStatus] = useState<"scanning" | "loading" | "error">(
    "scanning"
  );
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const handledRef = useRef(false);

  const handleScan = useCallback(
    async ({ data }: { data: string }) => {
      if (handledRef.current) {
        return;
      }
      handledRef.current = true;
      setStatus("loading");
      setErrorMessage(null);

      try {
        await redeemQrToken(data);
        await refreshMember();
        router.replace("/(tabs)");
      } catch (e) {
        if (e instanceof ApiError) {
          if (e.status === 404) setErrorMessage("QR을 찾을 수 없어요");
          else if (e.status === 409) setErrorMessage("이미 사용한 QR이에요");
          else if (e.status === 410) setErrorMessage("QR 시간이 지났어요");
          else setErrorMessage("로그인하지 못했어요");
        } else {
          setErrorMessage("로그인하지 못했어요");
        }
        setStatus("error");
      }
    },
    [refreshMember, router]
  );

  const handleRetry = useCallback(() => {
    handledRef.current = false;
    setErrorMessage(null);
    setStatus("scanning");
  }, []);

  if (!permission) {
    return (
      <View style={styles.container}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  if (!permission.granted) {
    const permissionState = describeCameraPermissionState(permission);

    if (permissionState === "blocked") {
      return (
        <View style={styles.container}>
          <Text style={styles.emoji}>📷</Text>
          <Text style={styles.title}>카메라 권한이 꺼져 있어요</Text>
          <Text style={styles.subtitle}>
            설정에서 카메라를 켜주세요
          </Text>
          <Pressable style={styles.button} onPress={Linking.openSettings}>
            <Text style={styles.buttonText}>설정에서 카메라 켜기</Text>
          </Pressable>
        </View>
      );
    }

    return (
      <View style={styles.container}>
        <Text style={styles.emoji}>📷</Text>
        <Text style={styles.title}>카메라를 보여주세요</Text>
        <Text style={styles.subtitle}>
          부모님 화면의 QR을 찍으려면 카메라를 써도 된다고 알려주세요
        </Text>
        <Pressable style={styles.button} onPress={requestPermission}>
          <Text style={styles.buttonText}>카메라 켜기</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {status === "scanning" && (
        <>
          <CameraView
            style={styles.camera}
            facing="back"
            barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
            onBarcodeScanned={handleScan}
          />
          <Text style={styles.hint}>
            부모님 화면에 보이는 QR을 카메라에 비춰주세요
          </Text>
        </>
      )}

      {status === "loading" && (
        <View style={styles.overlay}>
          <ActivityIndicator color={colors.accent} size="large" />
          <Text style={styles.loadingText}>연결하고 있어요...</Text>
        </View>
      )}

      {status === "error" && (
        <View style={styles.overlay}>
          <Text style={styles.emoji}>😢</Text>
          <Text style={styles.title}>{errorMessage}</Text>
          <Pressable style={styles.button} onPress={handleRetry}>
            <Text style={styles.buttonText}>다시 스캔하기</Text>
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
  },
  camera: {
    flex: 1,
  },
  hint: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
    textAlign: "center",
    backgroundColor: colors.bannerBackground,
    padding: 16,
  },
  overlay: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
  },
  loadingText: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
    marginTop: 12,
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
