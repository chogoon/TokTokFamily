import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/member.dart';
import '../models/room.dart';
import '../services/rooms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/daily_question.dart';
import '../utils/quick_replies.dart';
import '../utils/rooms.dart';

/// 채팅 화면. RN `frontend/app/room/[roomId].tsx`에 대응.
/// 메시지/반응/읽음은 모두 RoomsService(Supabase 직접 호출 + Realtime, RLS 범위)로만 다룬다.
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.me,
    required this.roomId,
    this.title = '대화',
  });

  /// 로그인한 구성원. 내 메시지 구분, 역할별 빠른답장 칩, 내 반응 찾기에 쓴다.
  final Member me;
  final String roomId;
  final String title;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final RoomsService _rooms = context.read<RoomsService>();
  final _draft = TextEditingController();
  final _scroll = ScrollController();

  Room? _room;
  List<ChatMessage> _messages = const [];
  Map<String, List<ReactionSummary>> _reactions = const {};
  bool _loading = true;
  String? _loadError;
  bool _sending = false;
  bool _stickersOpen = false;

  Unsubscribe? _unsubscribeMessages;
  Unsubscribe? _unsubscribeReactions;
  bool _urgentInFlight = false;

  // 화면을 연 날의 질문 (RN useMemo와 같게 화면 수명 동안 고정).
  final String _dailyQuestion = pickDailyQuestion(DateTime.now());

  @override
  void initState() {
    super.initState();
    _draft.addListener(() => setState(() {}));
    _load();
    _rooms.markRoomRead(widget.roomId).catchError((Object _) {
      // 읽음 처리 실패는 대화 화면 사용을 막지 않는다.
    });
    _unsubscribeMessages =
        _rooms.subscribeToMessages(widget.roomId, _onRealtimeMessage);
  }

  @override
  void dispose() {
    _unsubscribeMessages?.call();
    _unsubscribeReactions?.call();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _rooms.fetchRoomById(widget.roomId),
        _rooms.fetchMessages(widget.roomId),
      ]);
      if (!mounted) return;
      _room = results[0] as Room?;
      _setMessages(results[1] as List<ChatMessage>);
    } catch (_) {
      if (mounted) setState(() => _loadError = '대화를 불러오지 못했어요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onRealtimeMessage(ChatMessage message) {
    if (!mounted) return;
    // 재연결 등으로 같은 INSERT가 다시 오거나 초기 조회와 겹치면 무시한다.
    if (_messages.any((m) => m.id == message.id)) return;
    _setMessages([..._messages, message]);
    _rooms.markRoomRead(widget.roomId).catchError((Object _) {});
  }

  /// 메시지 목록을 바꾸고, 그 메시지들의 반응을 다시 읽고 반응 구독을 갱신한다.
  void _setMessages(List<ChatMessage> messages) {
    setState(() => _messages = messages);
    final ids = [for (final m in messages) m.id];
    _unsubscribeReactions?.call();
    _unsubscribeReactions = null;
    if (ids.isNotEmpty) {
      _unsubscribeReactions =
          _rooms.subscribeToReactions(ids, () => _reloadReactions());
    }
    _reloadReactions();
    _scrollToEnd();
  }

  Future<void> _reloadReactions() async {
    final ids = [for (final m in _messages) m.id];
    try {
      final result = await _rooms.fetchReactions(ids);
      if (mounted) setState(() => _reactions = result);
    } catch (_) {
      // 반응 조회 실패는 대화 화면 사용을 막지 않는다.
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _toast(String text, {ScaffoldMessengerState? messenger}) {
    final m = messenger ?? ScaffoldMessenger.maybeOf(context);
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bannerBackground,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        elevation: 0,
        duration: const Duration(milliseconds: 2200),
      ));
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _draft.clear();
    try {
      await _rooms.sendMessage(widget.roomId, body);
    } catch (_) {
      if (mounted) {
        // 보내지 못한 글은 다시 입력하지 않아도 되게 돌려놓는다.
        if (_draft.text.isEmpty) _draft.text = body;
        _toast('메시지를 보내지 못했어요');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendQuickReply(String text) async {
    try {
      await _rooms.sendMessage(widget.roomId, text);
    } catch (_) {
      if (mounted) _toast('메시지를 보내지 못했어요');
    }
  }

  /// 아이 긴급 칩: 지금 어느 방에 있든 아이 본인의 1:1방(보호자만 함께 보는 방)으로 긴급 전송한다.
  Future<void> _sendUrgent(String text) async {
    // fetchMyKidRoomId는 kid 역할 전제 (보호자 칩에는 긴급 칩이 없어 여기 도달하지 않는다).
    if (widget.me.role != MemberRole.kid || _urgentInFlight) return;
    _urgentInFlight = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      final kidRoomId = await _rooms.fetchMyKidRoomId();
      if (kidRoomId == null) {
        _toast('보낼 방을 찾지 못했어요', messenger: messenger);
        return;
      }
      await _rooms.sendMessage(kidRoomId, text, isUrgent: true);
      if (kidRoomId != widget.roomId && mounted) {
        navigator.pushReplacement(MaterialPageRoute<void>(
          builder: (_) => RoomScreen(
            me: widget.me,
            roomId: kidRoomId,
            title: '${widget.me.name}와의 대화',
          ),
        ));
      }
      _toast('🔔 엄마, 아빠에게 바로 알림이 갔어요!', messenger: messenger);
    } catch (_) {
      _toast('알림을 보내지 못했어요', messenger: messenger);
    } finally {
      _urgentInFlight = false;
    }
  }

  Future<void> _sendSticker(String emoji) async {
    setState(() => _stickersOpen = false);
    try {
      await _rooms.sendSticker(widget.roomId, emoji);
    } catch (_) {
      if (mounted) _toast('스티커를 보내지 못했어요');
    }
  }

  Future<void> _react(ChatMessage message) async {
    final current =
        myReactionEmoji(_reactions[message.id] ?? const [], widget.me.id);
    final next = nextReactionEmoji(reactionEmojis, current);
    try {
      await _rooms.toggleReaction(message.id, current, next);
      await _reloadReactions();
    } catch (_) {
      // 반응 저장 실패는 조용히 무시한다 (다음 탭에서 다시 시도 가능).
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Text(widget.title, style: AppTextStyles.cardTitle),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _ComposeArea(
              quickReplies:
                  quickRepliesFor(isKid: widget.me.role == MemberRole.kid),
              stickersOpen: _stickersOpen,
              draft: _draft,
              canSend: !_sending && _draft.text.trim().isNotEmpty,
              onQuickReply: (chip) => chip.urgent
                  ? _sendUrgent(chip.text)
                  : _sendQuickReply(chip.text),
              onToggleStickers: () =>
                  setState(() => _stickersOpen = !_stickersOpen),
              onSticker: _sendSticker,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 24),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    if (_loadError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_loadError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 14)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _load, child: const Text('다시 불러오기')),
          ),
        ],
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final maxBubbleWidth = constraints.maxWidth * 0.8;
      return ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          if (_room?.isFamily ?? false) _QuestionBanner(_dailyQuestion),
          if (_messages.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Text('아직 대화가 없어요. 첫 메시지를 보내볼까요?',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          for (final m in _messages)
            _MessageTile(
              key: ValueKey(m.id),
              message: m,
              isMine: m.senderId == widget.me.id,
              reactions: _reactions[m.id] ?? const [],
              maxWidth: maxBubbleWidth,
              onReact: () => _react(m),
            ),
        ],
      );
    });
  }
}

class _QuestionBanner extends StatelessWidget {
  const _QuestionBanner(this.question);

  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.bannerBackground,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 가족 질문',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bannerText)),
          const SizedBox(height: 4),
          Text(question, style: AppTextStyles.cardTitle),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    super.key,
    required this.message,
    required this.isMine,
    required this.reactions,
    required this.maxWidth,
    required this.onReact,
  });

  final ChatMessage message;
  final bool isMine;
  final List<ReactionSummary> reactions;
  final double maxWidth;
  final VoidCallback onReact;

  @override
  Widget build(BuildContext context) {
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final side = EdgeInsets.only(left: isMine ? 0 : 4, right: isMine ? 4 : 0);
    return Padding(
      // UI_GUIDE: 메시지 간 10px
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: align,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(message.senderName, style: AppTextStyles.meta),
                ),
              _Bubble(message: message, isMine: isMine),
              Padding(
                padding: side.add(const EdgeInsets.only(top: 4)),
                child: InkWell(
                  key: Key('react-${message.id}'),
                  borderRadius:
                      const BorderRadius.all(Radius.circular(AppRadius.pill)),
                  onTap: onReact,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final r in reactions)
                          if (r.memberIds.isNotEmpty) _ReactionChip(r),
                        const Opacity(
                          opacity: 0.6,
                          child: Text('＋',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: side.add(const EdgeInsets.only(top: 2)),
                child: Text(_formatTime(message.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final body = message.body ?? '';
    if (message.isSticker && !message.isUrgent) {
      return Text(body, style: const TextStyle(fontSize: 46, height: 52 / 46));
    }

    final Color background;
    final TextStyle style;
    if (message.isUrgent) {
      background = AppColors.dangerBackground;
      style = AppTextStyles.body
          .copyWith(color: AppColors.danger, fontWeight: FontWeight.w700);
    } else if (isMine) {
      background = AppColors.textPrimary;
      style = AppTextStyles.body.copyWith(color: AppColors.card);
    } else {
      background = AppColors.card;
      style = AppTextStyles.body;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
      ),
      child: Text(body, style: style),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip(this.reaction);

  final ReactionSummary reaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Text('${reaction.emoji} ${reaction.memberIds.length}',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
    );
  }
}

class _ComposeArea extends StatelessWidget {
  const _ComposeArea({
    required this.quickReplies,
    required this.stickersOpen,
    required this.draft,
    required this.canSend,
    required this.onQuickReply,
    required this.onToggleStickers,
    required this.onSticker,
    required this.onSend,
  });

  final List<QuickReply> quickReplies;
  final bool stickersOpen;
  final TextEditingController draft;
  final bool canSend;
  final void Function(QuickReply chip) onQuickReply;
  final VoidCallback onToggleStickers;
  final void Function(String emoji) onSticker;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pageBackground,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            // 칩이 7개뿐이라 lazy ListView 대신 Row로 모두 그린다 (RN 가로 ScrollView와 동일).
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (var i = 0; i < quickReplies.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _QuickReplyChip(
                      chip: quickReplies[i],
                      onTap: () => onQuickReply(quickReplies[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (stickersOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: LayoutBuilder(builder: (context, c) {
                final cell = c.maxWidth / 6;
                return Wrap(
                  children: [
                    for (final e in stickers)
                      SizedBox(
                        width: cell,
                        child: InkWell(
                          key: Key('sticker-$e'),
                          borderRadius: const BorderRadius.all(
                              Radius.circular(AppRadius.nav)),
                          onTap: () => onSticker(e),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Center(
                                child: Text(e,
                                    style: const TextStyle(fontSize: 30))),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                InkWell(
                  key: const Key('stickerToggle'),
                  customBorder: const CircleBorder(),
                  onTap: onToggleStickers,
                  child: Semantics(
                    label: stickersOpen ? '스티커 닫기' : '스티커 열기',
                    button: true,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                          child: Text('😊', style: TextStyle(fontSize: 24))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('messageInput'),
                    controller: draft,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(hintText: '메시지를 입력해요'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canSend ? onSend : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('보내기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  const _QuickReplyChip({required this.chip, required this.onTap});

  final QuickReply chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = chip.urgent;
    return Material(
      color: AppColors.card,
      shape: StadiumBorder(
        side: BorderSide(
          color: urgent ? AppColors.danger : AppColors.border,
          width: 1.5,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            widthFactor: 1,
            child: Text(
              chip.text,
              style: TextStyle(
                fontSize: 13,
                color: urgent ? AppColors.danger : AppColors.textPrimary,
                fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}
