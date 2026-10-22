import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invite.dart';
import '../models/member.dart';
import '../services/families_service.dart';
import '../services/members_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/api_error_messages.dart';
import '../utils/kid_palette.dart';
import '../widgets/member_avatar.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import 'qr_issue_screen.dart';

/// 가족 화면: 구성원 목록 + (보호자만) 아이 QR 연결 / 보호자 초대 / 아이 추가.
/// RN `frontend/app/(tabs)/family.tsx`에 대응. 구성원 목록은 Supabase 직접 조회(RLS 범위),
/// 초대/아이 추가는 backend 경유(ADR-004).
///
/// 형제 비교 화면 금지 원칙에 따라 구성원별 칭찬 개수 같은 비교 가능한 수치는 표시하지 않는다.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.me});

  /// 로그인한 구성원. role에 따라 보호자 전용 섹션 노출을 결정한다
  /// (실제 권한 검증은 backend/RLS가 하고, 여기서는 UI 노출만 가른다).
  final Member me;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<Member> _members = const [];
  bool _loadingMembers = true;
  String? _membersError;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loadingMembers = true;
      _membersError = null;
    });
    try {
      final result = await context.read<MembersService>().fetchFamilyMembers();
      if (!mounted) return;
      setState(() => _members = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _membersError = '가족 목록을 불러오지 못했어요');
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  void _openQrIssue(Member kid) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QrIssueScreen(kidMemberId: kid.id, kidName: kid.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.me.isParent;

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _loadMembers,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('👪 우리 가족', style: AppTextStyles.pageTitle),
              const SizedBox(height: 12),
              ..._buildMembers(isParent),
              if (isParent) ...[
                const SizedBox(height: 12),
                const _InviteSection(),
                const SizedBox(height: 12),
                _AddKidSection(
                  existingKidCount: countKids(_members),
                  onAdded: _loadMembers,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMembers(bool isParent) {
    if (_loadingMembers && _members.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      ];
    }
    if (_membersError != null) {
      return [
        Text(
          _membersError!,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _loadMembers,
            child: const Text('다시 불러오기'),
          ),
        ),
      ];
    }
    return [
      for (final m in _members)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MemberCard(
            member: m,
            onConnectQr: isParent && m.role == MemberRole.kid
                ? () => _openQrIssue(m)
                : null,
          ),
        ),
    ];
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, this.onConnectQr});

  final Member member;

  /// null이면 QR 버튼을 그리지 않는다 (보호자 화면의 아이 카드에만 전달).
  final VoidCallback? onConnectQr;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MemberAvatar(member: member, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  member.name,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (member.isParent) const _ParentBadge(),
            ],
          ),
          if (onConnectQr != null) ...[
            const SizedBox(height: 10),
            _SecondaryPillButton(
              label: 'QR로 로그인 연결하기',
              leading: '📱',
              onPressed: onConnectQr!,
            ),
          ],
        ],
      ),
    );
  }
}

/// 보호자/아이 권한 구분 배지 (UI_GUIDE 디자인 원칙 2).
class _ParentBadge extends StatelessWidget {
  const _ParentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.bannerBackground,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: const Text(
        '보호자',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.bannerText,
        ),
      ),
    );
  }
}

/// 보조 액션용 pill 버튼 (배너 톤). Primary(초록)와 구분된다.
class _SecondaryPillButton extends StatelessWidget {
  const _SecondaryPillButton({
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final String? leading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bannerBackground,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                Text(leading!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bannerText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteSection extends StatefulWidget {
  const _InviteSection();

  @override
  State<_InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends State<_InviteSection> {
  Invite? _invite;
  bool _loading = false;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await context.read<FamiliesService>().createInvite();
      if (mounted) setState(() => _invite = invite);
    } catch (e) {
      if (mounted) setState(() => _error = createInviteErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return SectionCard(
      title: '🔗 보호자 초대하기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (invite != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: const BoxDecoration(
                color: AppColors.bannerBackground,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: SelectableText(
                invite.code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const HintBanner('이 코드를 다른 보호자님께 알려주세요. 10분 안에 입력해야 해요.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _loading ? null : _create,
                child: const Text('새 코드 만들기'),
              ),
            ),
          ] else ...[
            const Text(
              '다른 보호자님(엄마·아빠 등)을 가족에 초대할 수 있어요.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: '초대 코드 만들기',
              loading: _loading,
              onPressed: _create,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddKidSection extends StatefulWidget {
  const _AddKidSection({required this.existingKidCount, required this.onAdded});

  final int existingKidCount;
  final Future<void> Function() onAdded;

  @override
  State<_AddKidSection> createState() => _AddKidSectionState();
}

class _AddKidSectionState extends State<_AddKidSection> {
  final _name = TextEditingController();
  String _avatar = kidAvatars.first;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nameError = validateKidName(_name.text);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<FamiliesService>().addKid(
            name: _name.text,
            avatar: _avatar,
            color: nextKidColor(widget.existingKidCount),
          );
      _name.clear();
      await widget.onAdded();
    } catch (e) {
      if (mounted) setState(() => _error = addKidErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 아이에게는 이름(별명)과 캐릭터만 받는다 — 전화번호/이메일/생년월일/학교 필드 추가 금지.
    return SectionCard(
      title: '👶 아이 추가하기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('kidNameField'),
            controller: _name,
            maxLength: maxKidNameLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: '아이 이름 또는 별명 (예: 서아)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          const Text('캐릭터 고르기', style: AppTextStyles.meta),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in kidAvatars)
                _AvatarOption(
                  key: Key('avatar-$a'),
                  emoji: a,
                  selected: a == _avatar,
                  onTap: () => setState(() => _avatar = a),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: '가족에 추가',
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 10),
          const HintBanner(
            '아이를 추가하면 그 아이와 엄마·아빠만 보는 1:1 방, 아이 전용 칭찬판이 자동으로 생겨요.',
          ),
        ],
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    super.key,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadius.nav));
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.bannerBackground : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.border,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }
}
