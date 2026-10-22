import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_logo.dart';
import 'family_screen.dart';

/// 메인 화면. 2단계에서는 가족 화면만 보여준다.
/// 대화/기분/칭찬 탭은 다음 단계에서 하단 탭으로 추가한다 (그때 FamilyScreen은 탭 하나가 된다).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            : FamilyScreen(key: ValueKey(member.id), me: member),
      ),
    );
  }
}
