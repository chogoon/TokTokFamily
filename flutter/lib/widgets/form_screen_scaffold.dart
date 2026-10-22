import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 인증 플로우 공통 레이아웃: 제목/부제 + 좌측 정렬 단일 컬럼(최대 440px) + 에러 문구.
class FormScreenScaffold extends StatelessWidget {
  const FormScreenScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.error,
    this.showBack = true,
    this.titleWidget,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? error;
  final bool showBack;
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (!showBack) const SizedBox(height: 48),
                titleWidget ?? Text(title, style: AppTextStyles.pageTitle),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.subtitle),
                const SizedBox(height: 24),
                ...children,
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
