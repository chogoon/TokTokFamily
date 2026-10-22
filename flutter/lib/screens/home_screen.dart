import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// 메인 화면 (1단계 임시 placeholder). 대화/기분/칭찬/가족 탭은 다음 단계에서 구현한다.
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
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
                  boxShadow: [
                    BoxShadow(color: AppColors.border, offset: Offset(0, 1)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '환영합니다, ${member?.name ?? ''}님!',
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '가족: ${auth.familyName ?? ''}',
                      style: AppTextStyles.subtitle,
                    ),
                    if (member != null) ...[
                      const SizedBox(height: 12),
                      _RoleBadge(isParent: member.isParent),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보호자/아이 권한 구분을 배지로 표시한다 (UI_GUIDE 디자인 원칙 2).
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isParent});

  final bool isParent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.bannerBackground,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Text(
        isParent ? '보호자' : '아이',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.bannerText,
        ),
      ),
    );
  }
}
