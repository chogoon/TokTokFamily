import { useFocusEffect } from "expo-router";
import { useCallback, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useAuth } from "../../contexts/AuthContext";
import { buildBoardSlots, buildGoalProgressText, isGoalReached } from "../../lib/praises";
import { colors } from "../../lib/theme";
import { fetchFamilyMembers } from "../../services/family";
import {
  addPraise,
  addPraiseToAllKids,
  claimReward,
  fetchActiveBoard,
  fetchPraises,
  saveGoal,
} from "../../services/praises";
import { Member } from "../../types/member";
import { PraiseBoard, PraiseEntry } from "../../types/praise";

export default function PraiseScreen() {
  const { member: me } = useAuth();
  const isParent = me?.role === "parent";

  const [members, setMembers] = useState<Member[]>([]);
  const [loadingMembers, setLoadingMembers] = useState(true);
  const [selectedKidId, setSelectedKidId] = useState<string | null>(null);

  const [board, setBoard] = useState<PraiseBoard | null>(null);
  const [praises, setPraises] = useState<PraiseEntry[]>([]);
  const [loadingBoard, setLoadingBoard] = useState(true);
  const [boardError, setBoardError] = useState<string | null>(null);

  const [praiseText, setPraiseText] = useState("");
  const [goalText, setGoalText] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const kids = members.filter((m) => m.role === "kid");

  const loadMembers = useCallback(async () => {
    setLoadingMembers(true);
    try {
      const result = await fetchFamilyMembers();
      setMembers(result);

      if (!isParent && me) {
        setSelectedKidId(me.id);
      } else {
        const kidList = result.filter((m) => m.role === "kid");
        setSelectedKidId((current) =>
          current && kidList.some((k) => k.id === current) ? current : kidList[0]?.id ?? null
        );
      }
    } finally {
      setLoadingMembers(false);
    }
  }, [isParent, me]);

  const loadBoard = useCallback(async () => {
    if (!selectedKidId) {
      setBoard(null);
      setPraises([]);
      setLoadingBoard(false);
      return;
    }

    setBoardError(null);
    setLoadingBoard(true);
    try {
      const activeBoard = await fetchActiveBoard(selectedKidId);
      setBoard(activeBoard);
      setGoalText(activeBoard?.goalText ?? "");

      if (activeBoard) {
        const entries = await fetchPraises(activeBoard.id);
        setPraises(entries);
      } else {
        setPraises([]);
      }
    } catch {
      setBoardError("칭찬판을 불러오지 못했어요");
    } finally {
      setLoadingBoard(false);
    }
  }, [selectedKidId]);

  useFocusEffect(
    useCallback(() => {
      loadMembers();
    }, [loadMembers])
  );

  useFocusEffect(
    useCallback(() => {
      loadBoard();
    }, [loadBoard])
  );

  async function handleAddPraise() {
    const text = praiseText.trim();
    if (!text || !board) {
      return;
    }
    setSubmitting(true);
    setNotice(null);
    try {
      await addPraise(board.id, text);
      setPraiseText("");
      await loadBoard();
      const reachedGoal = isGoalReached(praises.length + 1, board.targetCount);
      setNotice(reachedGoal ? "🎉 목표 달성! 약속을 지켜주세요" : "⭐ 스티커를 붙였어요");
    } catch {
      setNotice("칭찬을 추가하지 못했어요");
    } finally {
      setSubmitting(false);
    }
  }

  async function handleAddToAll() {
    const text = praiseText.trim();
    if (!text || kids.length === 0) {
      return;
    }
    setSubmitting(true);
    setNotice(null);
    try {
      await addPraiseToAllKids(kids.map((k) => k.id), text);
      setPraiseText("");
      await loadBoard();
      setNotice("👫 모두에게 스티커를 붙였어요");
    } catch {
      setNotice("칭찬을 추가하지 못했어요");
    } finally {
      setSubmitting(false);
    }
  }

  async function handleClaimReward() {
    if (!board) {
      return;
    }
    setSubmitting(true);
    setNotice(null);
    try {
      await claimReward(board);
      await loadBoard();
      setNotice("🎁 새 칭찬판이 시작됐어요");
    } catch {
      setNotice("보상을 처리하지 못했어요");
    } finally {
      setSubmitting(false);
    }
  }

  async function handleSaveGoal() {
    const text = goalText.trim();
    if (!text || !board) {
      return;
    }
    setSubmitting(true);
    setNotice(null);
    try {
      await saveGoal(board.id, text);
      await loadBoard();
      setNotice("🎯 목표를 저장했어요");
    } catch {
      setNotice("목표를 저장하지 못했어요");
    } finally {
      setSubmitting(false);
    }
  }

  const selectedKid = members.find((m) => m.id === selectedKidId) ?? null;
  const count = praises.length;
  const goalReached = board ? isGoalReached(count, board.targetCount) : false;
  const slots = board ? buildBoardSlots(count, board.targetCount) : [];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>⭐ 칭찬판</Text>

      {loadingMembers ? (
        <ActivityIndicator color={colors.accent} style={{ marginTop: 16 }} />
      ) : (
        <>
          {isParent && kids.length > 0 && (
            <View style={styles.kidSelRow}>
              {kids.map((kid) => (
                <Pressable
                  key={kid.id}
                  onPress={() => setSelectedKidId(kid.id)}
                  style={[
                    styles.kidPill,
                    kid.id === selectedKidId && {
                      backgroundColor: colors.textPrimary,
                      borderColor: colors.textPrimary,
                    },
                  ]}
                >
                  <Text
                    style={[
                      styles.kidPillText,
                      kid.id === selectedKidId && styles.kidPillTextSelected,
                    ]}
                  >
                    {kid.avatar ?? "🙂"} {kid.name}
                  </Text>
                </Pressable>
              ))}
            </View>
          )}

          {isParent && kids.length === 0 && (
            <Text style={styles.hint}>
              아이를 먼저 추가해 주세요. '가족' 탭에서 아이를 추가할 수 있어요.
            </Text>
          )}

          {selectedKidId && (
            <View style={styles.card}>
              {loadingBoard ? (
                <ActivityIndicator color={colors.accent} style={{ marginTop: 8 }} />
              ) : boardError ? (
                <Text style={styles.error}>{boardError}</Text>
              ) : !board ? (
                <Text style={styles.hint}>아직 칭찬판이 없어요</Text>
              ) : (
                <>
                  <Text style={styles.boardTitle}>
                    ⭐ {selectedKid?.name ?? "아이"}의 칭찬 스티커
                  </Text>
                  <Text style={styles.goalText}>
                    {buildGoalProgressText(board.goalText, count, board.targetCount)}
                  </Text>

                  <View style={styles.board}>
                    {slots.map((filled, i) => (
                      <View
                        key={i}
                        style={[
                          styles.slot,
                          filled && {
                            borderColor: selectedKid?.color ?? colors.kid,
                            backgroundColor: colors.bannerBackground,
                          },
                        ]}
                      >
                        {filled && <Text style={styles.slotStar}>⭐</Text>}
                      </View>
                    ))}
                  </View>

                  {isParent ? (
                    <View style={styles.parentArea}>
                      <TextInput
                        style={styles.input}
                        placeholder="무엇을 칭찬할까요? (예: 스스로 숙제했어요)"
                        value={praiseText}
                        onChangeText={setPraiseText}
                      />

                      {notice && <Text style={styles.notice}>{notice}</Text>}

                      <Pressable
                        style={[styles.button, submitting && styles.buttonDisabled]}
                        onPress={handleAddPraise}
                        disabled={submitting}
                      >
                        <Text style={styles.buttonText}>
                          {selectedKid?.name ?? "아이"}에게 스티커 붙여주기
                        </Text>
                      </Pressable>

                      {kids.length > 1 && (
                        <Pressable
                          style={[styles.buttonGhost, submitting && styles.buttonDisabled]}
                          onPress={handleAddToAll}
                          disabled={submitting}
                        >
                          <Text style={styles.buttonGhostText}>
                            👫 아이들 모두에게 붙여주기 (함께 한 일)
                          </Text>
                        </Pressable>
                      )}

                      {goalReached && (
                        <Pressable
                          style={[styles.buttonGift, submitting && styles.buttonDisabled]}
                          onPress={handleClaimReward}
                          disabled={submitting}
                        >
                          <Text style={styles.buttonText}>
                            🎁 약속 지켰어요! 새 판 시작하기
                          </Text>
                        </Pressable>
                      )}
                    </View>
                  ) : (
                    <View style={styles.lockBanner}>
                      <Text style={styles.lockText}>
                        🔒 칭찬 스티커는 엄마, 아빠가 붙여줄 수 있어요. 열심히 해보자!
                      </Text>
                      <Text style={styles.lockBadge}>보기만 가능</Text>
                    </View>
                  )}
                </>
              )}
            </View>
          )}

          {isParent && board && (
            <View style={styles.card}>
              <Text style={styles.cardTitle}>🎯 목표 바꾸기</Text>
              <TextInput
                style={styles.input}
                placeholder="예: 스티커 10개 모으면 보드게임 사기"
                value={goalText}
                onChangeText={setGoalText}
              />
              <Pressable
                style={[styles.buttonGhost, submitting && styles.buttonDisabled]}
                onPress={handleSaveGoal}
                disabled={submitting}
              >
                <Text style={styles.buttonGhostText}>목표 저장</Text>
              </Pressable>
              <Text style={styles.hint}>
                💡 아이마다 나이와 관심사에 맞게 목표를 따로 정할 수 있어요. 아이
                화면에는 자기 칭찬판만 보여서 형제끼리 비교되지 않아요.
              </Text>
            </View>
          )}

          {board && (
            <View style={styles.card}>
              <Text style={styles.cardTitle}>칭찬 기록</Text>
              {praises.length === 0 ? (
                <Text style={styles.hint}>아직 칭찬 기록이 없어요</Text>
              ) : (
                praises.map((p) => (
                  <View key={p.id} style={styles.praiseRow}>
                    <Text style={styles.praiseText}>
                      ⭐ {p.text} <Text style={styles.praiseGiver}>· {p.giverName}</Text>
                    </Text>
                  </View>
                ))
              )}
            </View>
          )}
        </>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.pageBackground,
  },
  content: {
    padding: 16,
  },
  title: {
    fontSize: 22,
    fontWeight: "800",
    letterSpacing: -0.5,
    color: colors.textPrimary,
    marginTop: 8,
    marginBottom: 12,
  },
  kidSelRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
    marginBottom: 12,
  },
  kidPill: {
    borderRadius: 999,
    borderWidth: 2,
    borderColor: colors.border,
    paddingHorizontal: 14,
    paddingVertical: 8,
    backgroundColor: colors.card,
  },
  kidPillText: {
    fontSize: 13,
    fontWeight: "700",
    color: colors.textPrimary,
  },
  kidPillTextSelected: {
    color: "#FFFFFF",
  },
  card: {
    backgroundColor: colors.card,
    borderRadius: 18,
    padding: 16,
    marginBottom: 12,
    shadowColor: colors.border,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 1,
    shadowRadius: 0,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
    marginBottom: 10,
  },
  boardTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
    marginBottom: 6,
  },
  goalText: {
    fontSize: 13,
    fontWeight: "700",
    color: colors.bannerText,
    backgroundColor: colors.bannerBackground,
    borderRadius: 12,
    padding: 10,
    marginBottom: 12,
  },
  board: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
    marginBottom: 12,
  },
  slot: {
    width: 36,
    height: 36,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: colors.border,
    alignItems: "center",
    justifyContent: "center",
  },
  slotStar: {
    fontSize: 16,
  },
  parentArea: {
    marginTop: 4,
  },
  input: {
    backgroundColor: "#FFFFFF",
    borderRadius: 999,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 15,
    borderWidth: 2,
    borderColor: colors.border,
    marginBottom: 10,
  },
  notice: {
    fontSize: 13,
    color: colors.bannerText,
    marginBottom: 8,
  },
  error: {
    color: colors.danger,
    fontSize: 13,
  },
  button: {
    backgroundColor: colors.accent,
    borderRadius: 999,
    paddingVertical: 14,
    alignItems: "center",
    marginBottom: 8,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "700",
  },
  buttonGhost: {
    borderRadius: 999,
    borderWidth: 2,
    borderColor: colors.border,
    paddingVertical: 12,
    alignItems: "center",
    marginBottom: 8,
  },
  buttonGhostText: {
    color: colors.textPrimary,
    fontSize: 14,
    fontWeight: "700",
  },
  buttonGift: {
    backgroundColor: colors.kid,
    borderRadius: 999,
    paddingVertical: 14,
    alignItems: "center",
    marginBottom: 8,
  },
  lockBanner: {
    backgroundColor: colors.bannerBackground,
    borderRadius: 12,
    padding: 12,
    marginTop: 4,
  },
  lockText: {
    fontSize: 13,
    color: colors.bannerText,
    marginBottom: 6,
  },
  lockBadge: {
    fontSize: 11,
    fontWeight: "700",
    color: colors.textSecondary,
    alignSelf: "flex-start",
    backgroundColor: colors.card,
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  hint: {
    fontSize: 12,
    color: colors.bannerText,
    backgroundColor: colors.bannerBackground,
    borderRadius: 12,
    padding: 10,
  },
  praiseRow: {
    paddingVertical: 6,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  praiseText: {
    fontSize: 14,
    color: colors.textPrimary,
  },
  praiseGiver: {
    fontSize: 11,
    fontWeight: "700",
    color: colors.textSecondary,
  },
});
