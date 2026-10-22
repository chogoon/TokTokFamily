import 'package:flutter/material.dart';

import 'app_colors.dart';

/// docs/UI_GUIDE.md 타이포그래피.
abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );
  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 1.4,
    color: AppColors.textPrimary,
  );
  static const subtitle = TextStyle(
    fontSize: 14,
    height: 1.4,
    color: AppColors.textSecondary,
  );
  static const meta = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );
}

/// 그림자 글로우/blur/그라데이션 없이 평평한 크림 톤 테마.
ThemeData buildAppTheme() {
  const pillBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
    borderSide: BorderSide(color: AppColors.border, width: 2),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.pageBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.kid,
      error: AppColors.danger,
      surface: AppColors.card,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.pageBackground,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      titleLarge: AppTextStyles.pageTitle,
      titleMedium: AppTextStyles.cardTitle,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      border: pillBorder,
      enabledBorder: pillBorder,
      focusedBorder: pillBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: pillBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      focusedErrorBorder: pillBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      errorStyle: const TextStyle(color: AppColors.danger, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.accentDisabled,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
