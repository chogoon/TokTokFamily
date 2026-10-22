import { useFocusEffect } from "expo-router";
import { useCallback, useMemo, useState } from "react";
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
import { buildWeeklyMoodDays, canSeeNote, MOODS } from "../../lib/moods";
import { colors } from "../../lib/theme";
import { fetchFamilyMembers } from "../../services/family";
import { fetchMyWeeklyMoods, fetchTodayMoods, saveMood } from "../../services/moods";
import { Member } from "../../types/member";
import { FamilyTodayMood, WeeklyMoodDay } from "../../types/mood";

interface KidWeek {
  member: Member;
  days: WeeklyMoodDay[];
}

export default function MoodScreen() {
  const { member: me } = useAuth();
  const isParent = me?.role === "parent";

  const [members, setMembers] = useState<Member[]>([]);
  const [todayMoods, setTodayMoods] = useState<FamilyTodayMood[]>([]);
  const [kidWeeks, setKidWeeks] = useState<KidWeek[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [pickedEmoji, setPickedEmoji] = useState<string | null>(null);
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [toastText, setToastText] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!me) return;
    setError(null);
    try {
      const [memberList, today] = await Promise.all([
        fetchFamilyMembers(),
        fetchTodayMoods(),
      ]);
      setMembers(memberList);
      setTodayMoods(today);

      const myToday = today.find((m) => m.memberId === me.id);
      setPickedEmoji(myToday?.emoji ?? null);

      // 주간 기록: 보호자는 모든 아이, 아이는 본인 것만
      const kids = isParent ? memberList.filter((m) => m.role === "kid") : [me];
      const weeks = await Promise.all(
        kids.map(async (kid) => {
          const weekMoods = await fetchMyWeeklyMoods(kid.id);
          const moodsByDate: Record<string, Record<string, { emoji: string; note?: string | null }>> = {};
          for (const entry of weekMoods) {
            moodsByDate[entry.date] ||= {};
            moodsByDate[entry.date][entry.memberId] = {
              emoji: entry.emoji,
              note: entry.note,
            };
          }
          const days = buildWeeklyMoodDays(kid.id, moodsByDate, new Date());
          return { member: kid, days };
        })
      );
      setKidWeeks(weeks);
    } catch {
      setError("기분 기록을 불러오지 못했어요");
    } finally {
      setLoading(false);
    }
  }, [me, isParent]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load])
  );

  const showToast = useCallback((text: string) => {
    setToastText(text);
    setTimeout(() => setToastText(null), 1800);
  }, []);

  async function handleSave() {
    if (!pickedEmoji) {
      showToast("기분을 하나 골라줘!");
      return;
    }
    setSaving(true);
    try {
      await saveMood(pickedEmoji, note.trim() || undefined);
      setNote("");
      const wasKid = me?.role === "kid";
      const alertEmojis = pickedEmoji === "😢" || pickedEmoji === "😠";
      showToast(
        wasKid && alertEmojis ? "엄마 아빠가 마음을 알게 됐어요 🤗" : "기분을 알려줬어요!"
      );
      await load();
    } catch {
      showToast("기분을 저장하지 못했어요");
    } finally {
      setSaving(false);
    }
  }

  const title = useMemo(() => {
    if (!me) return "오늘 기분은 어때?";
    return isParent ? `${me.name}의 오늘 기분` : `${me.name}야, 오늘 기분은 어때?`;
  }, [me, isParent]);

  const privacyHint = isParent
    ? "🔒 적은 이유는 부모님끼리만 보여요."
    : "🔒 이유는 엄마, 아빠만 볼 수 있어요. 슬프거나 화나면 엄마 아빠에게 살짝 알려줄게요.";

  if (loading) {
    return (
      <View style={styles.container}>
        <ActivityIndicator color={colors.accent} style={{ marginTop: 24 }} />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.pageTitle}>🌈 기분</Text>

      {error && <Text style={styles.error}>{error}</Text>}

      {/* 오늘 기분 선택 */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>{title}</Text>
        <View style={styles.moodRow}>
          {MOODS.map(({ emoji, label }) => {
            const selected = pickedEmoji === emoji;
            return (
              <Pressable
                key={emoji}
                style={[styles.moodButton, selected && styles.moodButtonSelected]}
                onPress={() => setPickedEmoji(emoji)}
              >
                <Text style={styles.moodEmoji}>{emoji}</Text>
                <Text style={styles.moodLabel}>{label}</Text>
              </Pressable>
            );
          })}
        </View>
        <TextInput
          style={styles.input}
          placeholder="왜 그런 기분이야? (안 써도 괜찮아)"
          value={note}
          onChangeText={setNote}
          maxLength={200}
        />
        <Pressable
          style={[styles.button, saving && styles.buttonDisabled]}
          onPress={handleSave}
          disabled={saving}
        >
          {saving ? (
            <ActivityIndicator color="#FFFFFF" />
          ) : (
            <Text style={styles.buttonText}>기분 알려주기</Text>
          )}
        </Pressable>
        <Text style={styles.hint}>{privacyHint}</Text>
        {toastText && <Text style={styles.toast}>{toastText}</Text>}
      </View>

      {/* 오늘 우리 가족 기분 */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>오늘 우리 가족 기분</Text>
        {members.map((member) => {
          const entry = todayMoods.find((m) => m.memberId === member.id);
          const visible = me ? canSeeNote(me.role, me.id, member.id) : false;
          return (
            <View key={member.id} style={styles.famMoodRow}>
              <Text style={styles.famMoodEmoji}>{entry?.emoji ?? "❔"}</Text>
              <View style={{ flex: 1 }}>
                <Text style={styles.famMoodName}>{member.name}</Text>
                {entry?.note && visible && (
                  <Text style={styles.famMoodNote}>&quot;{entry.note}&quot;</Text>
                )}
              </View>
            </View>
          );
        })}
      </View>

      {/* 주간 기록 */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>
          {isParent ? "아이들의 일주일 기분" : "나의 이번 주 기분"}
        </Text>
        {kidWeeks.length === 0 ? (
          <Text style={styles.hint}>아이를 먼저 추가해 주세요</Text>
        ) : (
          kidWeeks.map(({ member, days }) => (
            <View key={member.id} style={styles.weekBlock}>
              {isParent && (
                <Text style={styles.weekKidName}>
                  {member.avatar ?? "🙂"} {member.name}
                </Text>
              )}
              <View style={styles.weekRow}>
                {days.map((day) => (
                  <View key={day.date} style={styles.weekDay}>
                    <Text style={styles.weekDayEmoji}>{day.emoji ?? "·"}</Text>
                    <Text
                      style={[
                        styles.weekDayLabel,
                        day.isToday && styles.weekDayLabelToday,
                      ]}
                    >
                      {day.dayLabel}
                    </Text>
                  </View>
                ))}
              </View>
            </View>
          ))
        )}
      </View>
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
  pageTitle: {
    fontSize: 22,
    fontWeight: "800",
    letterSpacing: -0.5,
    color: colors.textPrimary,
    marginTop: 8,
    marginBottom: 12,
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
  moodRow: {
    flexDirection: "row",
    gap: 8,
    marginBottom: 10,
  },
  moodButton: {
    flex: 1,
    alignItems: "center",
    paddingVertical: 10,
    borderRadius: 14,
    borderWidth: 2,
    borderColor: colors.border,
  },
  moodButtonSelected: {
    borderColor: colors.kid,
    backgroundColor: colors.bannerBackground,
  },
  moodEmoji: {
    fontSize: 26,
  },
  moodLabel: {
    fontSize: 11,
    fontWeight: "700",
    color: colors.textSecondary,
    marginTop: 2,
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
  button: {
    backgroundColor: colors.accent,
    borderRadius: 999,
    paddingVertical: 14,
    alignItems: "center",
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "700",
  },
  hint: {
    fontSize: 12,
    color: colors.bannerText,
    backgroundColor: colors.bannerBackground,
    borderRadius: 12,
    padding: 10,
    marginTop: 10,
  },
  toast: {
    fontSize: 13,
    fontWeight: "700",
    color: colors.accent,
    marginTop: 8,
    textAlign: "center",
  },
  error: {
    fontSize: 14,
    color: colors.danger,
    marginBottom: 12,
  },
  famMoodRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  famMoodEmoji: {
    fontSize: 24,
    width: 32,
    textAlign: "center",
  },
  famMoodName: {
    fontSize: 14,
    fontWeight: "600",
    color: colors.textPrimary,
  },
  famMoodNote: {
    fontSize: 13,
    color: colors.textSecondary,
    marginTop: 2,
  },
  weekBlock: {
    marginBottom: 12,
  },
  weekKidName: {
    fontSize: 13,
    fontWeight: "700",
    color: colors.textPrimary,
    marginBottom: 6,
  },
  weekRow: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  weekDay: {
    alignItems: "center",
    flex: 1,
  },
  weekDayEmoji: {
    fontSize: 18,
  },
  weekDayLabel: {
    fontSize: 10,
    fontWeight: "700",
    color: colors.textSecondary,
    marginTop: 2,
  },
  weekDayLabelToday: {
    color: colors.kid,
  },
});
