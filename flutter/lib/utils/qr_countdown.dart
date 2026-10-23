// QR 발급 화면에서 "토큰 만료까지 남은 시간"을 보여주기 위한 순수 로직.
// RN `frontend/lib/qrCountdown.ts` 포팅. 타이머/네트워크 없이 테스트 가능하도록 분리했다.

/// [expiresAt] 기준으로 [now]로부터 남은 초. 1초 미만 잔여분은 올림하고, 음수는 0으로 clamp한다.
int remainingSeconds(DateTime expiresAt, DateTime now) {
  final diffMs = expiresAt.difference(now).inMilliseconds;
  if (diffMs <= 0) return 0;
  return (diffMs / 1000).ceil();
}

/// 남은 초를 "mm:ss"(분·초 모두 2자리 패딩)로 포맷한다.
String formatCountdown(int totalSeconds) {
  final clamped = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = (clamped ~/ 60).toString().padLeft(2, '0');
  final seconds = (clamped % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
