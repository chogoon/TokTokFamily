import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// UI_GUIDE 카드: radius 18, 흰 배경, `0 1px 0 #F0E6D6` 그림자, padding 16. 선택적 카드 제목.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        boxShadow: [BoxShadow(color: AppColors.border, offset: Offset(0, 1))],
      ),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title!, style: AppTextStyles.cardTitle),
                const SizedBox(height: 10),
                child,
              ],
            ),
    );
  }
}

/// 배너 톤 안내 문구 (보조 배경 + 안내 텍스트 색).
class HintBanner extends StatelessWidget {
  const HintBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.bannerBackground,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.bannerText,
        ),
      ),
    );
  }
}
