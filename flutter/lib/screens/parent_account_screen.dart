import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_auth_backend.dart';
import '../utils/validators.dart';
import '../widgets/app_logo.dart';
import '../widgets/form_screen_scaffold.dart';
import '../widgets/primary_button.dart';

/// 보호자 계정 만들기/로그인 (Supabase Auth 이메일+비밀번호).
/// RN `app/(auth)/sign-up.tsx`와 같은 순서: 먼저 Supabase Auth 계정 → 그 JWT로 backend `POST /families`.
/// 세션이 생기면 AuthController가 needsFamily로 바뀌고 AuthGate가 시작 화면(가족 만들기/참여)을 보여준다.
class ParentAccountScreen extends StatefulWidget {
  const ParentAccountScreen({super.key});

  @override
  State<ParentAccountScreen> createState() => _ParentAccountScreenState();
}

class _ParentAccountScreenState extends State<ParentAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignIn = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<ParentAuthService>();
    try {
      if (_isSignIn) {
        await auth.signIn(email: _email.text, password: _password.text);
      } else {
        final hasSession =
            await auth.signUp(email: _email.text, password: _password.text);
        if (!hasSession && mounted) {
          setState(() => _error = '이메일로 받은 확인 링크를 누른 뒤 로그인해주세요');
        }
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '잠시 후 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScreenScaffold(
      showBack: false,
      title: '우리가족톡톡',
      titleWidget: const AppLogo(),
      subtitle: _isSignIn ? '보호자 계정으로 로그인해요' : '보호자 계정을 만들어요',
      error: _error,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(hintText: '이메일'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: (v) => validateEmail(v ?? ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(hintText: '비밀번호'),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => validatePassword(v ?? ''),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _isSignIn ? '로그인' : '가입하기',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _isSignIn = !_isSignIn;
                      _error = null;
                    }),
            child: Text(_isSignIn ? '처음이신가요? 계정 만들기' : '이미 계정이 있나요? 로그인'),
          ),
        ),
      ],
    );
  }
}
