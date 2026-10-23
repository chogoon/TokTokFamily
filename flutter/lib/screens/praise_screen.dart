import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/praise.dart';
import '../services/members_service.dart';
import '../services/praises_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/kid_palette.dart';
import '../utils/praises.dart';
import '../widgets/section_card.dart';

/// 칭찬⭐ 탭: 아이별 칭찬 스티커판. RN `frontend/app/(tabs)/praise.tsx`에 대응.
///
/// CRITICAL (형제 비교 금지): 보호자의 아이 선택 pill에는 아바타+이름만 보여주고 칭찬 개수/진행률은
/// 절대 표시하지 않는다. 한 번에 선택된 아이 한 명의 판만 보인다. 아이는 본인 판만 보며(RLS도
/// 본인 판만 돌려준다) 입력 UI는 전부 숨기고 "보기만 가능"으로 표시한다.
class PraiseScreen extends StatefulWidget {
  const PraiseScreen({super.key, required this.me});

  final Member me;

  @override
  State<PraiseScreen> createState() => PraiseScreenState();
}

class PraiseScreenState extends State<PraiseScreen> {
  List<Member> _members = const [];
  bool _loadingMembers = true;
  String? _selectedKidId;

  PraiseBoard? _board;
  List<PraiseEntry> _praises = const [];
  bool _loadingBoard = true;
  String? _boardError;

  final _praiseController = TextEditingController();
  final _goalController = TextEditingController();
  bool _submitting = false;
  String? _notice;

  /// 빠르게 pill을 바꿀 때 늦게 도착한 이전 아이의 응답이 화면을 덮지 않도록 하는 일련번호.
  int _boardRequestSeq = 0;

  bool get _isParent => widget.me.isParent;

  List<Member> get _kids =>
      _members.where((m) => m.role == MemberRole.kid).toList();

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _praiseController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  /// 구성원 → 선택된 아이의 판을 다시 읽는다. 탭으로 돌아올 때 호출된다 (RN useFocusEffect 대응).
  Future<void> reload() async {
    await _loadMembers();
    await _loadBoard();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final result = await context.read<MembersService>().fetchFamilyMembers();
      if (!mounted) return;
      setState(() {
        _members = result;
        if (!_isParent) {
          // 아이는 언제나 본인 판만.
          _selectedKidId = widget.me.id;
        } else {
          final kids = result.where((m) => m.role == MemberRole.kid).toList();
          final current = _selectedKidId;
          _selectedKidId = current != null && kids.any((k) => k.id == current)
              ? current
              : (kids.isEmpty ? null : kids.first.id);
        }
      });
    } catch (_) {
      // RN과 동일하게 구성원 조회 실패는 별도 문구 없이 넘어간다 (아이 미선택 상태로 남음).
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadBoard() async {
    final kidId = _selectedKidId;
    final seq = ++_boardRequestSeq;
    if (kidId == null) {
      setState(() {
        _board = null;
        _praises = const [];
        _loadingBoard = false;
      });
      return;
    }

    setState(() {
      _boardError = null;
      _loadingBoard = true;
    });
    final service = context.read<PraisesService>();
    try {
      final board = await service.fetchActiveBoard(kidId);
      final entries = board == null
          ? const <PraiseEntry>[]
          : await service.fetchPraises(board.id);
      if (!mounted || seq != _boardRequestSeq) return;
      setState(() {
        _board = board;
        _goalController.text = board?.goalText ?? '';
        _praises = entries;
      });
    } catch (_) {
      if (!mounted || seq != _boardRequestSeq) return;
      setState(() => _boardError = '칭찬판을 불러오지 못했어요');
    } finally {
      if (mounted && seq == _boardRequestSeq) {
        setState(() => _loadingBoard = false);
      }
    }
  }

  void _selectKid(String kidId) {
    if (kidId == _selectedKidId) return;
    setState(() {
      _selectedKidId = kidId;
      _notice = null;
    });
    _loadBoard();
  }

  /// 제출 공통 흐름: submitting 표시 → 작업 → 판 다시 읽기 → 성공/실패 안내.
  Future<void> _submit(
    Future<void> Function() action, {
    required String Function() success,
    required String failure,
  }) async {
    setState(() {
      _submitting = true;
      _notice = null;
    });
    try {
      await action();
      await _loadBoard();
      if (mounted) setState(() => _notice = success());
    } catch (_) {
      if (mounted) setState(() => _notice = failure);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleAddPraise() async {
    final text = _praiseController.text.trim();
    final board = _board;
    if (text.isEmpty || board == null) return;
    // 추가 전 개수 + 1로 달성 여부를 판정한다 (RN과 동일).
    final reachedGoal = isGoalReached(_praises.length + 1, board.targetCount);
    await _submit(
      () async {
        await context.read<PraisesService>().addPraise(board.id, text);
        _praiseController.clear();
      },
      success: () => reachedGoal ? '🎉 목표 달성! 약속을 지켜주세요' : '⭐ 스티커를 붙였어요',
      failure: '칭찬을 추가하지 못했어요',
    );
  }

  Future<void> _handleAddToAll() async {
    final text = _praiseController.text.trim();
    final kids = _kids;
    if (text.isEmpty || kids.isEmpty) return;
    await _submit(
      () async {
        await context
            .read<PraisesService>()
            .addPraiseToAllKids([for (final k in kids) k.id], text);
        _praiseController.clear();
      },
      success: () => '👫 모두에게 스티커를 붙였어요',
      failure: '칭찬을 추가하지 못했어요',
    );
  }

  Future<void> _handleClaimReward() async {
    final board = _board;
    if (board == null) return;
    await _submit(
      () => context.read<PraisesService>().claimReward(board),
      success: () => '🎁 새 칭찬판이 시작됐어요',
      failure: '보상을 처리하지 못했어요',
    );
  }

  Future<void> _handleSaveGoal() async {
    final text = _goalController.text.trim();
    final board = _board;
    if (text.isEmpty || board == null) return;
    await _submit(
      () => context.read<PraisesService>().saveGoal(board.id, text),
      success: () => '🎯 목표를 저장했어요',
      failure: '목표를 저장하지 못했어요',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('⭐ 칭찬판', style: AppTextStyles.pageTitle),
            const SizedBox(height: 12),
            if (_loadingMembers)
              const _Spinner(top: 16)
            else
              ..._buildContent(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    final kids = _kids;
    final board = _board;
    return [
      if (_isParent && kids.isNotEmpty) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kid in kids)
              _KidPill(
                key: ValueKey('kid-pill-${kid.id}'),
                kid: kid,
                selected: kid.id == _selectedKidId,
                onTap: () => _selectKid(kid.id),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      if (_isParent && kids.isEmpty)
        const HintBanner("아이를 먼저 추가해 주세요. '가족' 탭에서 아이를 추가할 수 있어요."),
      if (_selectedKidId != null) ...[
        SectionCard(child: _buildBoardCard()),
        const SizedBox(height: 12),
      ],
      if (_isParent &&
          board != null &&
          !_loadingBoard &&
          _boardError == null) ...[
        _buildGoalCard(),
        const SizedBox(height: 12),
      ],
      if (board != null && !_loadingBoard && _boardError == null)
        _buildHistoryCard(),
    ];
  }

  Widget _buildBoardCard() {
    if (_loadingBoard) return const _Spinner(top: 8);
    if (_boardError != null) {
      return Text(_boardError!,
          style: const TextStyle(color: AppColors.danger, fontSize: 13));
    }
    final board = _board;
    if (board == null) return const HintBanner('아직 칭찬판이 없어요');

    final selectedKid =
        _members.where((m) => m.id == _selectedKidId).firstOrNull;
    final kidName = selectedKid?.name ?? '아이';
    final count = _praises.length;
    final goalReached = isGoalReached(count, board.targetCount);
    final slots = buildBoardSlots(count, board.targetCount);
    final slotColor = parseHexColor(selectedKid?.color) ?? AppColors.kid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('⭐ $kidName의 칭찬 스티커', style: AppTextStyles.cardTitle),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppColors.bannerBackground,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Text(
            buildGoalProgressText(board.goalText, count, board.targetCount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.bannerText,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filled in slots)
              _Slot(filled: filled, filledColor: slotColor),
          ],
        ),
        const SizedBox(height: 12),
        if (_isParent)
          _buildParentInputs(kidName, goalReached)
        else
          const _KidLockBanner(),
      ],
    );
  }

  Widget _buildParentInputs(String kidName, bool goalReached) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('praise-input'),
          controller: _praiseController,
          decoration: const InputDecoration(
            hintText: '무엇을 칭찬할까요? (예: 스스로 숙제했어요)',
          ),
        ),
        const SizedBox(height: 10),
        if (_notice != null) ...[
          Text(_notice!,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.bannerText)),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: _submitting ? null : _handleAddPraise,
          child: Text('$kidName에게 스티커 붙여주기'),
        ),
        if (_kids.length > 1) ...[
          const SizedBox(height: 8),
          _GhostButton(
            label: '👫 아이들 모두에게 붙여주기 (함께 한 일)',
            onPressed: _submitting ? null : _handleAddToAll,
          ),
        ],
        if (goalReached) ...[
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.kid,
              disabledBackgroundColor: AppColors.kid.withValues(alpha: 0.6),
            ),
            onPressed: _submitting ? null : _handleClaimReward,
            child: const Text('🎁 약속 지켰어요! 새 판 시작하기'),
          ),
        ],
      ],
    );
  }

  Widget _buildGoalCard() {
    return SectionCard(
      title: '🎯 목표 바꾸기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('goal-input'),
            controller: _goalController,
            decoration: const InputDecoration(
              hintText: '예: 스티커 10개 모으면 보드게임 사기',
            ),
          ),
          const SizedBox(height: 10),
          _GhostButton(
            label: '목표 저장',
            onPressed: _submitting ? null : _handleSaveGoal,
          ),
          const SizedBox(height: 8),
          const HintBanner(
            '💡 아이마다 나이와 관심사에 맞게 목표를 따로 정할 수 있어요. '
            '아이 화면에는 자기 칭찬판만 보여서 형제끼리 비교되지 않아요.',
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return SectionCard(
      title: '칭찬 기록',
      child: _praises.isEmpty
          ? const HintBanner('아직 칭찬 기록이 없어요')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in _praises)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Text.rich(TextSpan(
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary),
                      children: [
                        TextSpan(text: '⭐ ${p.text ?? ''} '),
                        TextSpan(
                            text: '· ${p.giverName}',
                            style: AppTextStyles.meta),
                      ],
                    )),
                  ),
              ],
            ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.top});

  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }
}

/// 아이 선택 pill. CRITICAL: 아바타+이름만 — 칭찬 개수/진행률 등 형제 비교 수치를 넣지 말 것.
class _KidPill extends StatelessWidget {
  const _KidPill({
    super.key,
    required this.kid,
    required this.selected,
    required this.onTap,
  });

  final Member kid;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.card,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.textPrimary : AppColors.border,
          width: 2,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            '${kid.avatar ?? '🙂'} ${kid.name}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.filled, required this.filledColor});

  final bool filled;
  final Color filledColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(filled ? 'praise-slot-filled' : 'praise-slot-empty'),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.bannerBackground : null,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(
          color: filled ? filledColor : AppColors.border,
          width: 2,
        ),
      ),
      child: filled ? const Text('⭐', style: TextStyle(fontSize: 16)) : null,
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size.fromHeight(46),
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.border, width: 2),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// 아이 화면: 입력 대신 "보기만 가능" 안내 (UI_GUIDE 디자인 원칙 2).
class _KidLockBanner extends StatelessWidget {
  const _KidLockBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.bannerBackground,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔒 칭찬 스티커는 엄마, 아빠가 붙여줄 수 있어요. 열심히 해보자!',
            style: TextStyle(fontSize: 13, color: AppColors.bannerText),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
            ),
            child: const Text('보기만 가능', style: AppTextStyles.meta),
          ),
        ],
      ),
    );
  }
}
