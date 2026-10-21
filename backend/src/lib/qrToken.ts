import { randomBytes } from "crypto";

const TTL_MS = 2 * 60 * 1000; // 2분 — QR은 화면에 잠깐 떴다 사라지는 용도라 짧게 유지

export function generateQrToken(): string {
  return randomBytes(24).toString("base64url");
}

export function qrTokenExpiresAt(): Date {
  return new Date(Date.now() + TTL_MS);
}
