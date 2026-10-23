import { randomBytes, randomInt } from "crypto";

const TTL_MS = 2 * 60 * 1000; // 2분 — QR/숫자 코드 모두 화면에 잠깐 떴다 사라지는 용도라 짧게 유지
const SHORT_CODE_DIGITS = 6;
const SHORT_CODE_MAX = 10 ** SHORT_CODE_DIGITS; // 1,000,000 (000000 ~ 999999)

export function generateQrToken(): string {
  return randomBytes(24).toString("base64url");
}

export function qrTokenExpiresAt(): Date {
  return new Date(Date.now() + TTL_MS);
}

/**
 * 카메라 없이 직접 입력할 숫자 6자리 코드를 생성한다. 앞자리 0도 허용되므로
 * 문자열로 패딩해 항상 6자리를 유지한다("012345" 등).
 */
export function generateShortCode(): string {
  return randomInt(SHORT_CODE_MAX).toString().padStart(SHORT_CODE_DIGITS, "0");
}
