import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// "우리가족톡톡" 로고 텍스트 ("톡톡"만 아이 포인트 색).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: AppTextStyles.pageTitle,
        children: [
          TextSpan(text: '우리가족'),
          TextSpan(text: '톡톡', style: TextStyle(color: AppColors.kid)),
        ],
      ),
    );
  }
}
