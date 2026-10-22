import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/families_service.dart';
import '../state/auth_controller.dart';
import '../utils/api_error_messages.dart';
import '../utils/validators.dart';
import '../widgets/form_screen_scaffold.dart';
import '../widgets/primary_button.dart';

/// 초대 코드로 참여하기 (보호자 전용). RN `app/(auth)/join-family.tsx`에 대응.
/// backend `POST /families/invites/redeem` (Supabase JWT 필요).
class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _parentName = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _parentName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final families = context.read<FamiliesService>();
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    try {
      await families.redeemInvite(
        code: _code.text,
        parentName: _parentName.text,
      );
      await auth.refreshMember();
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = redeemInviteErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScreenScaffold(
      title: '초대 코드로 참여하기',
      subtitle: '다른 보호자님께 받은 초대 코드와 보호자님 이름을 입력해주세요',
      error: _error,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(hintText: '초대 코드'),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                // 하이픈/공백 입력을 허용하므로 정규화 전 길이 기준으로 여유를 둔다
                maxLength: inviteCodeLength + 2,
                buildCounter: _noCounter,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => validateInviteCode(v ?? ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _parentName,
                decoration: const InputDecoration(hintText: '보호자님 이름'),
                maxLength: maxNameLength,
                buildCounter: _noCounter,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => validateParentName(v ?? ''),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: '참여하기',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) =>
    null;
