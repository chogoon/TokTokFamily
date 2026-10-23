import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/families_service.dart';
import '../state/auth_controller.dart';
import '../utils/api_error_messages.dart';
import '../utils/validators.dart';
import '../widgets/form_screen_scaffold.dart';
import '../widgets/primary_button.dart';

/// 가족 만들기. RN `app/(auth)/create-family.tsx`에 대응.
/// backend `POST /families` (Supabase JWT 필요) → refreshMember → AuthGate가 메인으로 전환.
class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyName = TextEditingController();
  final _parentName = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _familyName.dispose();
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
      await families.createFamily(
        familyName: _familyName.text,
        parentName: _parentName.text,
      );
      await auth.refreshMember();
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = createFamilyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScreenScaffold(
      title: '가족을 만들어요',
      subtitle: '가족 이름과 보호자님 이름을 알려주세요',
      error: _error,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _familyName,
                decoration: const InputDecoration(hintText: '가족 이름 (예: 우리가족)'),
                maxLength: maxNameLength,
                textInputAction: TextInputAction.next,
                validator: (v) => validateFamilyName(v ?? ''),
                buildCounter: _noCounter,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _parentName,
                decoration: const InputDecoration(hintText: '보호자님 이름'),
                maxLength: maxNameLength,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => validateParentName(v ?? ''),
                buildCounter: _noCounter,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: '가족 만들기',
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
