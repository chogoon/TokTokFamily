import { Session } from "@supabase/supabase-js";
import {
  createContext,
  PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useState,
} from "react";
import { Platform } from "react-native";
import { getPlatform, registerForPushNotificationsAsync } from "../lib/pushNotifications";
import { registerDevice } from "../services/devices";
import { fetchCurrentMember } from "../services/members";
import { supabase } from "../services/supabase";
import { Member } from "../types/member";

interface AuthState {
  session: Session | null;
  member: Member | null;
  loading: boolean;
  refreshMember: () => Promise<void>;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null);
  const [member, setMember] = useState<Member | null>(null);
  const [loading, setLoading] = useState(true);

  const refreshMember = useCallback(async () => {
    const current = await fetchCurrentMember();
    setMember(current);

    // 푸시 알림 등록은 선택 기능이다 — 권한 거부/실패가 로그인 흐름을 막지 않도록
    // 반드시 soft-fail 처리한다(throw 금지).
    if (current) {
      try {
        const token = await registerForPushNotificationsAsync();
        const platform = getPlatform(Platform.OS);
        if (token && platform) {
          await registerDevice(token, platform);
        }
      } catch {
        // 알림 등록 실패는 조용히 무시한다.
      }
    }
  }, []);

  useEffect(() => {
    let active = true;

    supabase.auth.getSession().then(async ({ data }) => {
      if (!active) return;
      setSession(data.session);
      if (data.session) {
        await refreshMember();
      }
      setLoading(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange(
      async (_event, newSession) => {
        setSession(newSession);
        if (newSession) {
          await refreshMember();
        } else {
          setMember(null);
        }
      }
    );

    return () => {
      active = false;
      subscription.subscription.unsubscribe();
    };
  }, [refreshMember]);

  return (
    <AuthContext.Provider value={{ session, member, loading, refreshMember }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return ctx;
}
