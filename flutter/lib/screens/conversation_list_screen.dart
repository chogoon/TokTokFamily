import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/room.dart';
import '../services/rooms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'room_screen.dart';

/// 대화 탭: 접근 가능한 방 목록. RN `frontend/app/(tabs)/index.tsx`에 대응.
/// 방 목록은 RLS가 돌려준 그대로 쓴다 (아이에게는 가족방 + 본인 1:1방만 온다).
class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key, required this.me});

  final Member me;

  @override
  State<ConversationListScreen> createState() => ConversationListScreenState();
}

class ConversationListScreenState extends State<ConversationListScreen> {
  List<RoomSummary> _rooms = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// 목록을 다시 읽는다. 탭으로 돌아올 때/채팅 화면에서 돌아올 때 호출된다 (RN useFocusEffect 대응).
  Future<void> reload() async {
    setState(() => _error = null);
    try {
      final result = await context.read<RoomsService>().fetchRooms();
      if (mounted) setState(() => _rooms = result);
    } catch (_) {
      if (mounted) setState(() => _error = '대화 목록을 불러오지 못했어요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(RoomSummary room) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          RoomScreen(me: widget.me, roomId: room.id, title: room.name),
    ));
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('💬 대화', style: AppTextStyles.pageTitle),
              const SizedBox(height: 12),
              ..._buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 24),
          child:
              Center(child: CircularProgressIndicator(color: AppColors.accent)),
        ),
      ];
    }
    if (_error != null) {
      return [
        Text(_error!,
            style: const TextStyle(fontSize: 14, color: AppColors.danger)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: reload, child: const Text('다시 불러오기')),
        ),
      ];
    }
    if (_rooms.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('아직 대화방이 없어요', style: AppTextStyles.subtitle),
        ),
      ];
    }
    return [
      for (final room in _rooms)
        Padding(
          // UI_GUIDE: 카드 간 12px
          padding: const EdgeInsets.only(bottom: 12),
          child: _RoomCard(room: room, onTap: () => _open(room)),
        ),
    ];
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});

  final RoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadius.card));
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [BoxShadow(color: AppColors.border, offset: Offset(0, 1))],
      ),
      child: Material(
        color: AppColors.card,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(room.name,
                          style: AppTextStyles.cardTitle,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (room.hasUnread) ...[
                      const SizedBox(width: 6),
                      Semantics(
                        label: '안 읽은 메시지',
                        child: Container(
                          key: Key('unread-${room.id}'),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  room.lastMessage?.body ?? '아직 대화가 없어요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
