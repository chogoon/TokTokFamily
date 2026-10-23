import { useFocusEffect, useRouter } from "expo-router";
import { useCallback, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { colors } from "../../lib/theme";
import { fetchRooms } from "../../services/rooms";
import { RoomSummary } from "../../types/room";

export default function RoomListScreen() {
  const router = useRouter();
  const [rooms, setRooms] = useState<RoomSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const result = await fetchRooms();
      setRooms(result);
    } catch {
      setError("대화 목록을 불러오지 못했어요");
    } finally {
      setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load])
  );

  return (
    <View style={styles.container}>
      <Text style={styles.title}>
        우리가족<Text style={{ color: colors.kid }}>톡톡</Text>
      </Text>

      {loading ? (
        <ActivityIndicator color={colors.accent} style={{ marginTop: 24 }} />
      ) : error ? (
        <Text style={styles.error}>{error}</Text>
      ) : rooms.length === 0 ? (
        <Text style={styles.empty}>아직 대화방이 없어요</Text>
      ) : (
        <FlatList
          data={rooms}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          renderItem={({ item }) => (
            <Pressable
              style={styles.roomCard}
              onPress={() => router.push(`/room/${item.id}`)}
            >
              <View style={styles.roomRow}>
                <Text style={styles.roomName}>{item.name}</Text>
                {item.hasUnread && <View style={styles.unreadDot} />}
              </View>
              <Text style={styles.roomPreview} numberOfLines={1}>
                {item.lastMessage?.body ?? "아직 대화가 없어요"}
              </Text>
            </Pressable>
          )}
        />
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
    letterSpacing: -0.5,
    color: colors.textPrimary,
    marginTop: 8,
    marginBottom: 16,
  },
  list: {
    gap: 12,
  },
  roomCard: {
    backgroundColor: colors.card,
    borderRadius: 18,
    padding: 16,
    shadowColor: colors.border,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 1,
    shadowRadius: 0,
  },
  roomRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  roomName: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.textPrimary,
  },
  unreadDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.danger,
  },
  roomPreview: {
    fontSize: 13,
    color: colors.textSecondary,
    marginTop: 6,
  },
  error: {
    fontSize: 14,
    color: colors.danger,
    marginTop: 24,
  },
  empty: {
    fontSize: 14,
    color: colors.textSecondary,
    marginTop: 24,
  },
});
