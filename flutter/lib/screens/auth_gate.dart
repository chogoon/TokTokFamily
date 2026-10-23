import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'parent_account_screen.dart';
import 'start_screen.dart';

/// 인증 상태에 따라 루트 화면을 고른다. RN `app/index.tsx`의 Redirect 분기에 대응.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>((a) => a.status);
    switch (status) {
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        );
      case AuthStatus.signedOut:
        return const ParentAccountScreen();
      case AuthStatus.needsFamily:
        return const StartScreen();
      case AuthStatus.ready:
        return const HomeScreen();
    }
  }
}
