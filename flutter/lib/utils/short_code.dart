// 아이 로그인용 6자리 숫자 코드 표시 로직. RN `frontend/lib/shortCode.ts` 포팅.
// 아이 기기 쪽 입력 정제(sanitize/isComplete)는 아이 로그인 화면 단계에서 추가한다.

/// 6자리 코드를 가운데 공백을 넣어 "482 913" 형태로 표시한다. 6자리가 아니면 그대로 반환한다.
String formatShortCode(String code) {
  if (code.length != 6) return code;
  return '${code.substring(0, 3)} ${code.substring(3)}';
}
