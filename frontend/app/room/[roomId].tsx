import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useAuth } from "../../contexts/AuthContext";
import { colors } from "../../lib/theme";
import {
  fetchMessages,
  markRoomRead,
  sendMessage,
  subscribeToMessages,
} from "../../services/rooms";
import { Message } from "../../types/message";

export default function RoomScreen() {
  const { roomId } = useLocalSearchParams<{ roomId: string }>();
  const router = useRouter();
  const { member } = useAuth();

  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const listRef = useRef<FlatList<Message>>(null);

  useEffect(() => {
    if (!roomId) {
      return;
    }

    let active = true;
    setLoading(true);

    fetchMessages(roomId)
      .then((result) => {
        if (active) {
          setMessages(result);
        }
      })
      .finally(() => {
        if (active) {
          setLoading(false);
        }
      });

    markRoomRead(roomId).catch(() => {
      // 읽음 처리 실패는 대화 화면 사용을 막지 않는다.
    });

    const unsubscribe = subscribeToMessages(roomId, (message) => {
      if (!active) {
        return;
      }
      setMessages((prev) => [...prev, message]);
      markRoomRead(roomId).catch(() => {});
    });

    return () => {
      active = false;
      unsubscribe();
    };
  }, [roomId]);

  const handleSend = useCallback(async () => {
    const body = draft.trim();
    if (!body || !roomId || sending) {
      return;
    }

    setSending(true);
    setDraft("");
    try {
      await sendMessage(roomId, body);
    } finally {
      setSending(false);
    }
  }, [draft, roomId, sending]);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <Stack.Screen options={{ headerShown: false }} />

      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backButtonText}>{"<"}</Text>
        </Pressable>
        <Text style={styles.headerTitle}>대화</Text>
      </View>

      {loading ? (
        <ActivityIndicator color={colors.accent} style={{ marginTop: 24 }} />
      ) : (
        <FlatList
          ref={listRef}
          data={messages}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
          renderItem={({ item }) => {
            const isMine = item.senderId === member?.id;
            return (
              <View style={[styles.messageRow, isMine && styles.messageRowMine]}>
                {!isMine && <Text style={styles.senderName}>{item.senderName}</Text>}
                <View style={[styles.bubble, isMine && styles.bubbleMine]}>
                  <Text style={[styles.bubbleText, isMine && styles.bubbleTextMine]}>
                    {item.body}
                  </Text>
                </View>
                <Text style={[styles.time, isMine && styles.timeMine]}>
                  {formatTime(item.createdAt)}
                </Text>
              </View>
            );
          }}
          ListEmptyComponent={
            <Text style={styles.empty}>아직 대화가 없어요. 첫 메시지를 보내볼까요?</Text>
          }
        />
      )}

      <View style={styles.composeRow}>
        <TextInput
          style={styles.input}
          placeholder="메시지를 입력해요"
          value={draft}
          onChangeText={setDraft}
          onSubmitEditing={handleSend}
          returnKeyType="send"
        />
        <Pressable
          style={[styles.sendButton, (sending || !draft.trim()) && styles.sendButtonDisabled]}
          onPress={handleSend}
          disabled={sending || !draft.trim()}
        >
          <Text style={styles.sendButtonText}>보내기</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

function formatTime(iso: string): string {
  const date = new Date(iso);
  const h = date.getHours();
  const m = String(date.getMinutes()).padStart(2, "0");
  return `${h}:${m}`;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.pageBackground,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingTop: 12,
    paddingBottom: 8,
    gap: 8,
  },
  backButton: {
    width: 32,
    height: 32,
    alignItems: "center",
    justifyContent: "center",
  },
  backButtonText: {
    fontSize: 18,
    fontWeight: "700",
    color: colors.textPrimary,
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
  },
  list: {
    padding: 16,
    gap: 10,
  },
  messageRow: {
    alignItems: "flex-start",
    marginVertical: 5,
    maxWidth: "80%",
  },
  messageRowMine: {
    alignSelf: "flex-end",
    alignItems: "flex-end",
  },
  senderName: {
    fontSize: 11,
    fontWeight: "700",
    color: colors.textSecondary,
    marginBottom: 2,
    marginLeft: 4,
  },
  bubble: {
    backgroundColor: colors.card,
    borderRadius: 18,
    paddingHorizontal: 13,
    paddingVertical: 10,
  },
  bubbleMine: {
    backgroundColor: colors.textPrimary,
  },
  bubbleText: {
    fontSize: 15,
    lineHeight: 15 * 1.4,
    color: colors.textPrimary,
  },
  bubbleTextMine: {
    color: "#FFFFFF",
  },
  time: {
    fontSize: 10,
    color: colors.textSecondary,
    marginTop: 2,
    marginLeft: 4,
  },
  timeMine: {
    marginRight: 4,
  },
  empty: {
    fontSize: 13,
    color: colors.textSecondary,
    textAlign: "left",
    marginTop: 30,
  },
  composeRow: {
    flexDirection: "row",
    gap: 8,
    padding: 12,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    backgroundColor: colors.pageBackground,
  },
  input: {
    flex: 1,
    backgroundColor: "#FFFFFF",
    borderRadius: 999,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 15,
    borderWidth: 2,
    borderColor: colors.border,
  },
  sendButton: {
    backgroundColor: colors.accent,
    borderRadius: 999,
    paddingHorizontal: 18,
    justifyContent: "center",
  },
  sendButtonDisabled: {
    opacity: 0.5,
  },
  sendButtonText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "700",
  },
});
