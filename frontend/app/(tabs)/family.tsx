import { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useAuth } from "../../contexts/AuthContext";
import { KID_AVATARS, KID_COLORS } from "../../lib/kidPalette";
import { colors } from "../../lib/theme";
import { ApiError } from "../../services/api";
import { addKid } from "../../services/families";
import { fetchFamilyMembers } from "../../services/family";
import { Member } from "../../types/member";

function nextColor(existingKidCount: number): string {
  return KID_COLORS[existingKidCount % KID_COLORS.length];
}

export default function FamilyScreen() {
  const { member: me } = useAuth();
  const [members, setMembers] = useState<Member[]>([]);
  const [loadingMembers, setLoadingMembers] = useState(true);
  const [name, setName] = useState("");
  const [avatar, setAvatar] = useState<string>(KID_AVATARS[0]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadMembers = useCallback(async () => {
    setLoadingMembers(true);
    try {
      const result = await fetchFamilyMembers();
      setMembers(result);
    } finally {
      setLoadingMembers(false);
    }
  }, []);

  useEffect(() => {
    loadMembers();
  }, [loadMembers]);

  async function handleAddKid() {
    if (!name.trim()) {
      setError("이름을 적어주세요");
      return;
    }

    setError(null);
    setSubmitting(true);
    try {
      const kidCount = members.filter((m) => m.role === "kid").length;
      await addKid(name.trim(), avatar, nextColor(kidCount));
      setName("");
      await loadMembers();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "아이를 추가하지 못했어요");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>👪 우리 가족</Text>

      <FlatList
        data={members}
        keyExtractor={(item) => item.id}
        style={styles.memberList}
        renderItem={({ item }) => (
          <View style={styles.memberRow}>
            <View
              style={[
                styles.memberAvatar,
                { backgroundColor: item.color ?? colors.border },
              ]}
            >
              <Text style={styles.memberAvatarText}>
                {item.avatar ?? (item.role === "parent" ? "👤" : "🙂")}
              </Text>
            </View>
            <Text style={styles.memberName}>{item.name}</Text>
            {item.role === "parent" && (
              <Text style={styles.memberBadge}>보호자</Text>
            )}
          </View>
        )}
        ListEmptyComponent={
          loadingMembers ? (
            <ActivityIndicator color={colors.accent} style={{ marginTop: 16 }} />
          ) : null
        }
      />

      {me?.role === "parent" && (
        <View style={styles.addCard}>
          <Text style={styles.addTitle}>👶 아이 추가하기</Text>

          <TextInput
            style={styles.input}
            placeholder="아이 이름 (예: 서아)"
            maxLength={8}
            value={name}
            onChangeText={setName}
          />

          <View style={styles.avatarGrid}>
            {KID_AVATARS.map((a) => (
              <Pressable
                key={a}
                onPress={() => setAvatar(a)}
                style={[
                  styles.avatarOption,
                  a === avatar && styles.avatarOptionSelected,
                ]}
              >
                <Text style={styles.avatarOptionText}>{a}</Text>
              </Pressable>
            ))}
          </View>

          {error && <Text style={styles.error}>{error}</Text>}

          <Pressable
            style={[styles.button, submitting && styles.buttonDisabled]}
            onPress={handleAddKid}
            disabled={submitting}
          >
            {submitting ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.buttonText}>가족에 추가</Text>
            )}
          </Pressable>

          <Text style={styles.hint}>
            아이를 추가하면 그 아이와 엄마·아빠만 보는 1:1 방, 아이 전용 칭찬판이
            자동으로 생겨요.
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.pageBackground,
    padding: 16,
  },
  title: {
    fontSize: 22,
    fontWeight: "800",
    color: colors.textPrimary,
    marginTop: 8,
    marginBottom: 12,
  },
  memberList: {
    flexGrow: 0,
    maxHeight: 200,
  },
  memberRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: colors.card,
    borderRadius: 18,
    padding: 12,
    marginBottom: 8,
  },
  memberAvatar: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 10,
  },
  memberAvatarText: {
    fontSize: 18,
  },
  memberName: {
    fontSize: 15,
    fontWeight: "600",
    color: colors.textPrimary,
    flex: 1,
  },
  memberBadge: {
    fontSize: 11,
    fontWeight: "700",
    color: colors.textSecondary,
  },
  addCard: {
    backgroundColor: colors.card,
    borderRadius: 18,
    padding: 16,
    marginTop: 12,
  },
  addTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
    marginBottom: 10,
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
  avatarGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 6,
    marginBottom: 10,
  },
  avatarOption: {
    width: 44,
    height: 44,
    borderRadius: 10,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 2,
    borderColor: "transparent",
  },
  avatarOptionSelected: {
    borderColor: colors.accent,
    backgroundColor: colors.bannerBackground,
  },
  avatarOptionText: {
    fontSize: 24,
  },
  error: {
    color: colors.danger,
    fontSize: 13,
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
});
