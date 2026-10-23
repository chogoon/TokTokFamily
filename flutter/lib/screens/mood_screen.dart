import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/mood.dart';
import '../services/members_service.dart';
import '../services/moods_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/moods.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

/// 기분 탭: 오늘 기분 고르기 / 오늘 우리 가족 기분 / 주간 기록. RN `frontend/app/(tabs)/mood.tsx`에 대응.
///
/// 제품 원칙: 이모지는 가족 전체 공개, 이유(note)는 본인+보호자만. RLS(mood_notes_select)가
/// 1차로 거르고, 이 화면은 note를 그리기 전에 반드시 [canSeeNote]로 한 번 더 확인한다.
/// 아이에게는 본인 주간 기록만 조회/표시한다 (형제 기록 경로 없음).
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key, required this.me});

  final Member me;

  @override
  State<MoodScreen> createState() => MoodScreenState();
}

class _KidWeek {
  const _KidWeek(this.member, this.days);
  final Member member;
  final List<WeeklyMoodDay> days;
}

class MoodScreenState extends State<MoodScreen> {
  static const _noteMaxLength = 200;

  final _note = TextEditingController();

  List<Member> _members = const [];
  List<FamilyTodayMood> _today = const [];
  List<_KidWeek> _weeks = const [];
  bool _loading = true;
  String? _error;

  String? _picked;
  bool _saving = false;

  bool get _isParent => widget.me.isParent;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// 기분 기록을 다시 읽는다. 탭으로 돌아올 때/저장 후 호출된다 (RN useFocusEffect 대응).
  Future<void> reload() async {
    final membersService = context.read<MembersService>();
    final moodsService = context.read<MoodsService>();
    setState(() => _error = null);
    try {
      final (members, today) = await (
        membersService.fetchFamilyMembers(),
        moodsService.fetchTodayMoods(),
      ).wait;

      // 주간 기록: 보호자는 모든 아이, 아이는 본인 것만 (형제 것은 조회조차 하지 않는다).
      final targets = _isParent
          ? members.where((m) => m.role == MemberRole.kid).toList()
          : [widget.me];
      final now = DateTime.now();
      final weeks = await Future.wait(targets.map((kid) async {
        final entries = await moodsService.fetchMyWeeklyMoods(kid.id);
        return _KidWeek(
            kid, buildWeeklyMoodDays(kid.id, groupMoodsByDate(entries), now));
      }));

      if (!mounted) return;
      setState(() {
        _members = members;
        _today = today;
        _weeks = weeks;
        _picked = _todayOf(widget.me.id)?.emoji ?? _picked;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '기분 기록을 불러오지 못했어요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  FamilyTodayMood? _todayOf(String memberId) {
    for (final m in _today) {
      if (m.memberId == memberId) return m;
    }
    return null;
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
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

  Future<void> _save() async {
    final emoji = _picked;
    if (emoji == null) {
      _toast('기분을 하나 골라줘!');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final note = _note.text.trim();
    try {
      final notified = await context
          .read<MoodsService>()
          .saveMood(emoji, note: note.isEmpty ? null : note);
      if (!mounted) return;
      _note.clear();
      // 알림 문구는 실제로 1:1방 알림을 보냈을 때만 (보호자/좋은 기분/방 없음이면 일반 문구).
      _toast(notified ? '엄마 아빠가 마음을 알게 됐어요 🤗' : '기분을 알려줬어요!');
      await reload();
    } catch (_) {
      _toast('기분을 저장하지 못했어요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              const Text('🌈 기분', style: AppTextStyles.pageTitle),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else ...[
                if (_error != null) ...[
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.danger)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: reload, child: const Text('다시 불러오기')),
                  ),
                  const SizedBox(height: 4),
                ],
                _buildPickCard(),
                const SizedBox(height: 12),
                _buildFamilyCard(),
                const SizedBox(height: 12),
                _buildWeeklyCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickCard() {
    final title = _isParent
        ? '${widget.me.name}의 오늘 기분'
        : '${widget.me.name}아, 오늘 기분은 어때?';
    final privacyHint = _isParent
        ? '🔒 적은 이유는 부모님끼리만 보여요.'
        : '🔒 이유는 엄마, 아빠만 볼 수 있어요. 슬프거나 화나면 엄마 아빠에게 살짝 알려줄게요.';

    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (i, m) in moods.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MoodButton(
                    emoji: m.emoji,
                    label: m.label,
                    selected: _picked == m.emoji,
                    onTap: () => setState(() => _picked = m.emoji),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: _noteMaxLength,
            decoration: const InputDecoration(
              hintText: '왜 그런 기분이야? (안 써도 괜찮아)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(label: '기분 알려주기', loading: _saving, onPressed: _save),
          const SizedBox(height: 10),
          HintBanner(privacyHint),
        ],
      ),
    );
  }

  Widget _buildFamilyCard() {
    return SectionCard(
      title: '오늘 우리 가족 기분',
      child: Column(
        children: [
          for (final member in _members) _buildFamilyRow(member),
        ],
      ),
    );
  }

  Widget _buildFamilyRow(Member member) {
    final entry = _todayOf(member.id);
    // 2차 방어: RLS가 돌려준 note라도 본인/보호자가 아니면 그리지 않는다 (형제 note 차단).
    final note = entry?.note;
    final showNote = note != null &&
        note.isNotEmpty &&
        canSeeNote(widget.me.role, widget.me.id, member.id);

    return Container(
      key: Key('today-${member.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(entry?.emoji ?? '❔',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (showNote) ...[
                  const SizedBox(height: 2),
                  Text('"$note"',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard() {
    return SectionCard(
      title: _isParent ? '아이들의 일주일 기분' : '나의 이번 주 기분',
      child: _weeks.isEmpty
          ? const HintBanner('아이를 먼저 추가해 주세요')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, week) in _weeks.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildWeekBlock(week),
                ],
              ],
            ),
    );
  }

  Widget _buildWeekBlock(_KidWeek week) {
    final kid = week.member;
    return Column(
      key: Key('week-${kid.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isParent) ...[
          Text('${kid.avatar ?? '🙂'} ${kid.name}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            for (final day in week.days)
              Expanded(
                child: Column(
                  key: day.isToday ? Key('week-${kid.id}-today') : null,
                  children: [
                    Text(day.emoji ?? '·',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(
                      day.dayLabel,
                      style: AppTextStyles.meta.copyWith(
                        fontSize: 10,
                        color: day.isToday ? AppColors.kid : null,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 이모지 선택 버튼. 선택되면 아이 포인트색 테두리 + 보조 배경으로 강조한다.
class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadius.nav));
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 기분',
      child: Material(
        key: Key(selected ? 'mood-$emoji-selected' : 'mood-$emoji'),
        color: selected ? AppColors.bannerBackground : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.kid : AppColors.border,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 2),
                Text(label, style: AppTextStyles.meta),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
