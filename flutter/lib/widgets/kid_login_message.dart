import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 아이 로그인 화면 공통: 큰 이모지 + 제목 + 설명 + 큰 버튼 (글보다 이모지/큰 버튼 우선).
class KidLoginMessage extends StatelessWidget {
  const KidLoginMessage({
    super.key,
    required this.emoji,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(emoji, style: const TextStyle(fontSize: 56)),
        ),
        const SizedBox(height: 12),
        Text(title, style: AppTextStyles.pageTitle),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(description!, style: AppTextStyles.subtitle),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 24),
          KidBigButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
  }
}

/// 아이용 큰 pill 버튼 (Primary 색, 높이 56).
class KidBigButton extends StatelessWidget {
  const KidBigButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// 아이 로그인 화면 공통 레이아웃: 좌측 정렬 단일 컬럼(최대 440px) + 하단 링크.
class KidLoginLayout extends StatelessWidget {
  const KidLoginLayout({
    super.key,
    required this.children,
    this.footer,
  });

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                ...children,
                if (footer != null) ...[
                  const SizedBox(height: 16),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 전환용 텍스트 링크 (아이 포인트 색).
class KidLoginLink extends StatelessWidget {
  const KidLoginLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
