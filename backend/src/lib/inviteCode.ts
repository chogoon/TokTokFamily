import { randomInt } from "crypto";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 혼동되는 문자(I/O/0/1) 제외
const LENGTH = 8;
const TTL_MS = 10 * 60 * 1000; // 10분

export function generateInviteCode(): string {
  let code = "";
  for (let i = 0; i < LENGTH; i++) {
    code += ALPHABET[randomInt(ALPHABET.length)];
  }
  return code;
}

export function inviteExpiresAt(): Date {
  return new Date(Date.now() + TTL_MS);
}
