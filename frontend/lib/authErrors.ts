// sign-in 화면에서 Supabase 에러 메시지를 사용자에게 보여줄 문구로 변환하는 순수 로직.
// 계정 존재 여부가 노출되지 않도록 "잘못된 비밀번호"와 "존재하지 않는 계정"을 구분하지 않고
// 하나의 일반화된 문구로 합친다.

/** Supabase가 반환하는 로그인 실패 메시지를 사용자용 한국어 문구로 변환한다. */
export function mapSignInErrorMessage(message: string): string {
  const normalized = message.toLowerCase();

  if (
    normalized.includes("invalid login credentials") ||
    normalized.includes("invalid email or password") ||
    normalized.includes("user not found")
  ) {
    return "이메일 또는 비밀번호가 올바르지 않아요.";
  }

  if (normalized.includes("email not confirmed")) {
    return "이메일 인증을 아직 완료하지 않았어요. 가입 시 받은 메일을 확인해주세요.";
  }

  if (normalized.includes("too many requests") || normalized.includes("rate limit")) {
    return "잠시 후 다시 시도해주세요.";
  }

  return "로그인에 실패했어요. 잠시 후 다시 시도해주세요.";
}
