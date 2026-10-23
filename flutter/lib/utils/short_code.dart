// 아이 로그인용 6자리 숫자 코드 로직. RN `frontend/lib/shortCode.ts` 포팅.

const shortCodeLength = 6;

final _nonDigit = RegExp(r'[^0-9]');
final _complete = RegExp(r'^[0-9]{6}$');

/// 6자리 코드를 가운데 공백을 넣어 "482 913" 형태로 표시한다. 6자리가 아니면 그대로 반환한다.
String formatShortCode(String code) {
  if (code.length != shortCodeLength) return code;
  return '${code.substring(0, 3)} ${code.substring(3)}';
}

/// 사용자 입력에서 ASCII 숫자만 남기고 최대 6자리로 자른다.
String sanitizeShortCodeInput(String input) {
  final digits = input.replaceAll(_nonDigit, '');
  return digits.length > shortCodeLength
      ? digits.substring(0, shortCodeLength)
      : digits;
}

/// 정확히 6자리 숫자인지 확인한다(자동 제출 트리거용).
bool isCompleteShortCode(String code) => _complete.hasMatch(code);
