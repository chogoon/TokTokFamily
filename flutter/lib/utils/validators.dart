// 입력 검증 순수 함수. 반환값이 null이면 통과, 문자열이면 화면에 보여줄 에러 문구.
// 길이 제한은 backend/src/routes/families.ts의 zod 스키마(max 100)와 맞춘다.

const int maxNameLength = 100;

/// backend/src/lib/inviteCode.ts의 ALPHABET/LENGTH와 동일 (혼동 문자 I/O/0/1 제외).
const String inviteCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int inviteCodeLength = 8;

final RegExp _inviteCodePattern =
    RegExp('^[$inviteCodeAlphabet]{$inviteCodeLength}\$');
final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateFamilyName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '가족 이름을 입력해주세요';
  if (trimmed.length > maxNameLength) return '가족 이름은 $maxNameLength자 이하로 적어주세요';
  return null;
}

String? validateParentName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '보호자님 이름을 입력해주세요';
  if (trimmed.length > maxNameLength) return '이름은 $maxNameLength자 이하로 적어주세요';
  return null;
}

/// 사용자가 띄어쓰기/하이픈을 섞어 입력해도 backend가 기대하는 형태(대문자 8자)로 맞춘다.
String normalizeInviteCode(String value) =>
    value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

String? validateInviteCode(String value) {
  final code = normalizeInviteCode(value);
  if (code.isEmpty) return '초대 코드를 입력해주세요';
  if (!_inviteCodePattern.hasMatch(code)) {
    return '초대 코드는 $inviteCodeLength자리예요';
  }
  return null;
}

/// 보호자 계정 전용. 아이 계정에는 이메일을 받지 않는다 (CLAUDE.md 제품 원칙).
String? validateEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '이메일을 입력해주세요';
  if (!_emailPattern.hasMatch(trimmed)) return '이메일 형식이 올바르지 않아요';
  return null;
}

String? validatePassword(String value) {
  if (value.length < 6) return '비밀번호는 6자 이상이어야 해요';
  return null;
}
