import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useAuth } from "../../contexts/AuthContext";
import { pickDailyQuestion } from "../../lib/dailyQuestion";
import { KID_QUICK_REPLIES, PARENT_QUICK_REPLIES, STICKERS } from "../../lib/quickReplies";
import { nextReactionEmoji, REACTION_EMOJIS } from "../../lib/rooms";
import { colors } from "../../lib/theme";
import {
  fetchMessages,
  fetchMyKidRoomId,
  fetchReactions,
  fetchRoomById,
  markRoomRead,
  sendMessage,
  sendSticker,
  subscribeToMessages,
  subscribeToReactions,
  toggleReaction,
} from "../../services/rooms";
import { Message, ReactionSummary } from "../../types/message";
import { Room } from "../../types/room";

export default function RoomScreen() {
  const { roomId } = useLocalSearchParams<{ roomId: string }>();
  const router = useRouter();
  const { member } = useAuth();

  const [room, setRoom] = useState<Room | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [reactionsByMessage, setReactionsByMessage] = useState<
    Record<string, ReactionSummary[]>
  >({});
  const [loading, setLoading] = useState(true);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [stickersOpen, setStickersOpen] = useState(false);
  const [toastText, setToastText] = useState<string | null>(null);
  const listRef = useRef<FlatList<Message>>(null);

  const showToast = useCallback((text: string) => {
    setToastText(text);
    setTimeout(() => setToastText(null), 2200);
  }, []);

  const reloadReactions = useCallback((messageIds: string[]) => {
    fetchReactions(messageIds)
      .then(setReactionsByMessage)
      .catch(() => {
        // 반응 조회 실패는 대화 화면 사용을 막지 않는다.
      });
  }, []);

  useEffect(() => {
    if (!roomId) {
      return;
    }

    let active = true;
    setLoading(true);

    Promise.all([fetchRoomById(roomId), fetchMessages(roomId)])
      .then(([roomResult, messageResult]) => {
        if (!active) return;
        setRoom(roomResult);
        setMessages(messageResult);
        reloadReactions(messageResult.map((m) => m.id));
      })
      .finally(() => {
        if (active) {
          setLoading(false);
        }
      });

    markRoomRead(roomId).catch(() => {
      // 읽음 처리 실패는 대화 화면 사용을 막지 않는다.
    });

    const unsubscribeMessages = subscribeToMessages(roomId, (message) => {
      if (!active) {
        return;
      }
      setMessages((prev) => [...prev, message]);
      markRoomRead(roomId).catch(() => {});
    });

    return () => {
      active = false;
      unsubscribeMessages();
    };
  }, [roomId, reloadReactions]);

  // 메시지 목록이 바뀔 때마다(새 메시지 포함) 그 메시지들의 반응 변경을 구독한다.
  useEffect(() => {
    if (messages.length === 0) {
      return;
    }
    const messageIds = messages.map((m) => m.id);
    const unsubscribe = subscribeToReactions(messageIds, () => {
      reloadReactions(messageIds);
    });
    return unsubscribe;
  }, [messages, reloadReactions]);

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

  const handleQuickReply = useCallback(
    async (text: string) => {
      if (!roomId) return;
      await sendMessage(roomId, text);
    },
    [roomId]
  );

  const handleUrgent = useCallback(
    async (text: string) => {
      try {
        const kidRoomId = await fetchMyKidRoomId();
        if (!kidRoomId) {
          showToast("보낼 방을 찾지 못했어요");
          return;
        }
        await sendMessage(kidRoomId, text, { isUrgent: true });
        if (kidRoomId !== roomId) {
          router.replace(`/room/${kidRoomId}`);
        }
        showToast("🔔 엄마, 아빠에게 바로 알림이 갔어요!");
      } catch {
        showToast("알림을 보내지 못했어요");
      }
    },
    [roomId, router, showToast]
  );

  const handleSticker = useCallback(
    async (emoji: string) => {
      if (!roomId) return;
      setStickersOpen(false);
      await sendSticker(roomId, emoji);
    },
    [roomId]
  );

  const handleReact = useCallback(
    async (message: Message) => {
      if (!member) return;
      const reactions = reactionsByMessage[message.id] ?? [];
      const currentEmoji = reactions.find((r) => r.memberIds.includes(member.id))?.emoji;
      const nextEmoji = nextReactionEmoji(REACTION_EMOJIS, currentEmoji);
      try {
        await toggleReaction(message.id, currentEmoji, nextEmoji);
        reloadReactions(messages.map((m) => m.id));
      } catch {
        // 반응 저장 실패는 조용히 무시한다 (다음 탭에서 다시 시도 가능).
      }
    },
    [member, messages, reactionsByMessage, reloadReactions]
  );

  const quickReplies = member?.role === "kid" ? KID_QUICK_REPLIES : PARENT_QUICK_REPLIES;
  const dailyQuestion = useMemo(() => pickDailyQuestion(new Date()), []);

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
          ListHeaderComponent={
            room?.type === "family" ? (
              <View style={styles.questionBanner}>
                <Text style={styles.questionLabel}>오늘의 가족 질문</Text>
                <Text style={styles.questionText}>{dailyQuestion}</Text>
              </View>
            ) : null
          }
          renderItem={({ item }) => {
            const isMine = item.senderId === member?.id;
            const reactions = reactionsByMessage[item.id] ?? [];
            const isSticker = item.kind === "sticker";
            return (
              <View style={[styles.messageRow, isMine && styles.messageRowMine]}>
                {!isMine && <Text style={styles.senderName}>{item.senderName}</Text>}
                <View
                  style={[
                    styles.bubble,
                    isMine && styles.bubbleMine,
                    isSticker && styles.bubbleSticker,
                    item.isUrgent && styles.bubbleUrgent,
                  ]}
                >
                  <Text
                    style={[
                      styles.bubbleText,
                      isMine && styles.bubbleTextMine,
                      isSticker && styles.bubbleTextSticker,
                      item.isUrgent && styles.bubbleTextUrgent,
                    ]}
                  >
                    {item.body}
                  </Text>
                </View>
                <Pressable
                  style={[styles.reactRow, isMine && styles.reactRowMine]}
                  onPress={() => handleReact(item)}
                >
                  {reactions
                    .filter((r) => r.memberIds.length > 0)
                    .map((r) => (
                      <Text key={r.emoji} style={styles.reactChip}>
                        {r.emoji} {r.memberIds.length}
                      </Text>
                    ))}
                  <Text style={styles.reactAdd}>＋</Text>
                </Pressable>
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

      {toastText && <Text style={styles.toast}>{toastText}</Text>}

      <View style={styles.composeArea}>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.chipsRow}
        >
          {quickReplies.map((chip) => (
            <Pressable
              key={chip.text}
              style={[styles.chip, chip.urgent && styles.chipUrgent]}
              onPress={() => (chip.urgent ? handleUrgent(chip.text) : handleQuickReply(chip.text))}
            >
              <Text style={[styles.chipText, chip.urgent && styles.chipTextUrgent]}>
                {chip.text}
              </Text>
            </Pressable>
          ))}
        </ScrollView>

        {stickersOpen && (
          <View style={styles.stickerGrid}>
            {STICKERS.map((emoji) => (
              <Pressable
                key={emoji}
                style={styles.stickerButton}
                onPress={() => handleSticker(emoji)}
              >
                <Text style={styles.stickerEmoji}>{emoji}</Text>
              </Pressable>
            ))}
          </View>
        )}

        <View style={styles.composeRow}>
          <Pressable
            style={styles.stickerToggle}
            onPress={() => setStickersOpen((open) => !open)}
          >
            <Text style={styles.stickerToggleText}>😊</Text>
          </Pressable>
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
  questionBanner: {
    backgroundColor: colors.bannerBackground,
    borderRadius: 18,
    padding: 14,
    marginBottom: 12,
  },
  questionLabel: {
    fontSize: 11,
    fontWeight: "700",
    color: colors.bannerText,
  },
  questionText: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
    marginTop: 4,
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
  bubbleSticker: {
    backgroundColor: "transparent",
    paddingHorizontal: 0,
    paddingVertical: 0,
  },
  bubbleUrgent: {
    backgroundColor: colors.dangerBackground,
  },
  bubbleText: {
    fontSize: 15,
    lineHeight: 15 * 1.4,
    color: colors.textPrimary,
  },
  bubbleTextMine: {
    color: "#FFFFFF",
  },
  bubbleTextSticker: {
    fontSize: 46,
    lineHeight: 52,
  },
  bubbleTextUrgent: {
    color: colors.danger,
    fontWeight: "700",
  },
  reactRow: {
    flexDirection: "row",
    gap: 4,
    marginTop: 4,
    marginLeft: 4,
    alignItems: "center",
  },
  reactRowMine: {
    marginLeft: 0,
    marginRight: 4,
  },
  reactChip: {
    fontSize: 12,
    backgroundColor: "#FFFFFF",
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 999,
    paddingHorizontal: 6,
    paddingVertical: 1,
    color: colors.textPrimary,
  },
  reactAdd: {
    fontSize: 13,
    color: colors.textSecondary,
    opacity: 0.6,
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
  toast: {
    fontSize: 13,
    fontWeight: "700",
    color: colors.textPrimary,
    backgroundColor: colors.bannerBackground,
    textAlign: "center",
    marginHorizontal: 16,
    marginBottom: 6,
    borderRadius: 999,
    paddingVertical: 8,
  },
  composeArea: {
    borderTopWidth: 1,
    borderTopColor: colors.border,
    backgroundColor: colors.pageBackground,
    paddingTop: 8,
  },
  chipsRow: {
    gap: 6,
    paddingHorizontal: 12,
    paddingBottom: 8,
  },
  chip: {
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: "#FFFFFF",
    borderRadius: 999,
    paddingHorizontal: 11,
    paddingVertical: 7,
  },
  chipUrgent: {
    borderColor: colors.danger,
  },
  chipText: {
    fontSize: 13,
    color: colors.textPrimary,
  },
  chipTextUrgent: {
    color: colors.danger,
    fontWeight: "700",
  },
  stickerGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    paddingHorizontal: 12,
    paddingBottom: 8,
  },
  stickerButton: {
    width: "16.66%",
    alignItems: "center",
    paddingVertical: 4,
  },
  stickerEmoji: {
    fontSize: 30,
  },
  composeRow: {
    flexDirection: "row",
    gap: 8,
    paddingHorizontal: 12,
    paddingBottom: 12,
  },
  stickerToggle: {
    width: 40,
    alignItems: "center",
    justifyContent: "center",
  },
  stickerToggleText: {
    fontSize: 22,
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
