// 아이 로그인용 6자리 숫자 코드를 다루는 순수 로직.
// 표시용 포맷팅과 입력 정제/완성 여부 판단을 네트워크 없이 테스트하기 위해 분리했다.

/** 6자리 숫자 코드를 가운데 공백을 넣어 "482 913" 형태로 표시한다. 6자리가 아니면 그대로 반환한다. */
export function formatShortCode(code: string): string {
  if (code.length !== 6) {
    return code;
  }
  return `${code.slice(0, 3)} ${code.slice(3)}`;
}

/** 사용자 입력에서 숫자만 남기고 최대 6자리로 자른다. */
export function sanitizeShortCodeInput(input: string): string {
  return input.replace(/\D/g, "").slice(0, 6);
}

/** 정확히 6자리 숫자인지 확인한다(자동 제출 트리거용). */
export function isCompleteShortCode(code: string): boolean {
  return /^\d{6}$/.test(code);
}
