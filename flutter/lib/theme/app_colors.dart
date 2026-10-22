import 'package:flutter/material.dart';

/// docs/UI_GUIDE.md 색상 토큰 (family-sns.html 프로토타입에서 추출).
/// RN `frontend/lib/theme.ts`와 같은 이름/값을 유지한다.
abstract final class AppColors {
  static const pageBackground = Color(0xFFFFF8EE);
  static const card = Color(0xFFFFFFFF);
  static const bannerBackground = Color(0xFFF6EEDD);
  static const textPrimary = Color(0xFF2B2A33);
  static const textSecondary = Color(0xFF8A8494);
  static const bannerText = Color(0xFF6A5A44);
  static const kid = Color(0xFFFFB547);
  static const accent = Color(0xFF6BCB77);
  /// accent 60% 불투명 (비활성 버튼)
  static const accentDisabled = Color(0x996BCB77);
  static const danger = Color(0xFFC2364A);
  static const dangerBackground = Color(0xFFFFE5E8);
  static const border = Color(0xFFF0E6D6);
}

/// 모서리 반경. 카드 18 / 버튼·입력 999(pill) / Nav 14 로 구분한다 (균일한 rounded 금지).
abstract final class AppRadius {
  static const card = 18.0;
  static const pill = 999.0;
  static const nav = 14.0;
}
