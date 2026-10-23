import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../state/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'conversation_list_screen.dart';
import 'family_screen.dart';

/// 메인 탭 셸: 대화💬 / 기분🌈 / 칭찬⭐ / 가족👪. RN `frontend/app/(tabs)/_layout.tsx`에 대응.
/// 로고 + 로그아웃 AppBar는 모든 탭이 공유하고, 각 탭 화면은 본문 상단에 자체 제목을 그린다.
/// 채팅 화면(RoomScreen)은 탭 밖에서 push되므로 하단 탭이 가려진다 (RN `app/room/[roomId]`와 동일).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _conversationKey = GlobalKey<ConversationListScreenState>();

  static const _tabs = [
    (emoji: '💬', label: '대화'),
    (emoji: '🌈', label: '기분'),
    (emoji: '⭐', label: '칭찬'),
    (emoji: '👪', label: '가족'),
  ];

  void _select(int index) {
    // 대화 탭에 다시 들어오면 안읽음/마지막 메시지를 새로 읽는다 (RN useFocusEffect).
    if (index == 0 && _index != 0) _conversationKey.currentState?.reload();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final member = auth.member;

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(),
        centerTitle: false,
        actions: [
          TextButton(onPressed: auth.signOut, child: const Text('로그아웃')),
        ],
      ),
      body: SafeArea(
        child: member == null
            // AuthGate가 ready일 때만 보여주므로 보통은 도달하지 않는다.
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : KeyedSubtree(
                key: ValueKey(member.id),
                child: _buildTabs(member),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        backgroundColor: AppColors.card,
        // RN처럼 인디케이터 없이 이모지 투명도로만 포커스를 표시한다.
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: _TabIcon(t.emoji, focused: false),
              selectedIcon: _TabIcon(t.emoji, focused: true),
              label: t.label,
            ),
        ],
      ),
    );
  }

  Widget _buildTabs(Member member) {
    return IndexedStack(
      index: _index,
      children: [
        ConversationListScreen(key: _conversationKey, me: member),
        const _ComingSoonTab(emoji: '🌈', title: '오늘의 기분'),
        const _ComingSoonTab(emoji: '⭐', title: '칭찬판'),
        FamilyScreen(me: member),
      ],
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon(this.emoji, {required this.focused});

  final String emoji;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: focused ? 1 : 0.5,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}

/// 기분/칭찬 탭 자리표시. 다음 단계에서 실제 화면으로 교체된다.
class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.emoji, required this.title});

  final String emoji;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji $title', style: AppTextStyles.pageTitle),
          const SizedBox(height: 12),
          const Text('다음 단계에서 구현됩니다', style: AppTextStyles.subtitle),
        ],
      ),
    );
  }
}
