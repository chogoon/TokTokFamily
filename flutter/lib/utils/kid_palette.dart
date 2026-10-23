import 'dart:ui' show Color;

import '../models/member.dart';

// backend/src/lib/kidPalette.ts의 KID_COLORS/KID_AVATARS와 같은 목록.
// backend zod가 enum으로 검증하므로 바꿀 때는 backend·frontend(RN)·여기 세 곳을 함께 맞춘다.
// 이 색들은 "아이 멤버 식별색"이라는 데이터 값이지 UI 토큰이 아니다 (UI 색은 theme/app_colors.dart).

const List<String> kidColors = [
  '#FFB547',
  '#6BCB77',
  '#B28DFF',
  '#FF9F68',
  '#4FC3C7',
  '#F48FB1',
  '#9CCC65',
];

const List<String> kidAvatars = [
  '🐣',
  '🦖',
  '🐰',
  '🦊',
  '🐼',
  '🐯',
  '🐨',
  '🦄',
  '🐸',
  '🐧',
];

/// backend `POST /families/kids` zod 스키마의 name max(8)와 동일.
const int maxKidNameLength = 8;

/// 기존 아이 수에 따라 KID_COLORS를 순환 선택한다 (RN family.tsx의 nextColor).
String nextKidColor(int existingKidCount) =>
    kidColors[existingKidCount % kidColors.length];

int countKids(Iterable<Member> members) =>
    members.where((m) => m.role == MemberRole.kid).length;

bool isValidKidAvatar(String avatar) => kidAvatars.contains(avatar);

/// 아이 이름(별명) 검증. 아이에게는 이름/캐릭터 외 개인정보를 받지 않는다.
/// 길이는 JS string length와 같은 UTF-16 code unit 기준 (Dart String.length).
String? validateKidName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '이름을 적어주세요';
  if (trimmed.length > maxKidNameLength) {
    return '이름은 $maxKidNameLength자 이하로 적어주세요';
  }
  return null;
}

final RegExp _hexColor = RegExp(r'^#([0-9a-fA-F]{6})$');

/// members.color("#RRGGBB")를 Color로. 형식이 틀리거나 null이면 null(호출부에서 테마 색으로 대체).
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final match = _hexColor.firstMatch(hex);
  if (match == null) return null;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}
