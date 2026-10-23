import { Tabs } from "expo-router";
import { Text } from "react-native";
import { colors } from "../../lib/theme";

function TabIcon({ emoji, focused }: { emoji: string; focused: boolean }) {
  return (
    <Text style={{ fontSize: 18, opacity: focused ? 1 : 0.5 }}>{emoji}</Text>
  );
}

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.textPrimary,
        tabBarInactiveTintColor: colors.textSecondary,
        tabBarStyle: { backgroundColor: colors.card },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: "대화",
          tabBarIcon: ({ focused }) => <TabIcon emoji="💬" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="mood"
        options={{
          title: "기분",
          tabBarIcon: ({ focused }) => <TabIcon emoji="🌈" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="praise"
        options={{
          title: "칭찬",
          tabBarIcon: ({ focused }) => <TabIcon emoji="⭐" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="family"
        options={{
          title: "가족",
          tabBarIcon: ({ focused }) => <TabIcon emoji="👪" focused={focused} />,
        }}
      />
    </Tabs>
  );
}
