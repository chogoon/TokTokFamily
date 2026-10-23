// qr-issue 화면에서 "QR 토큰 만료까지 남은 시간"을 보여주기 위한 순수 로직.
// 네트워크/타이머 없이 테스트 가능하도록 분리했다.

/** expiresAt(ISO 문자열) 기준으로 now로부터 남은 초를 반환한다. 음수는 0으로 clamp한다. */
export function remainingSeconds(expiresAt: string, now: Date): number {
  const diffMs = new Date(expiresAt).getTime() - now.getTime();
  return Math.max(0, Math.ceil(diffMs / 1000));
}

/** 남은 초를 "분:초" 형태(초는 2자리 패딩)로 포맷한다. */
export function formatCountdown(totalSeconds: number): string {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}
