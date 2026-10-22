import { mapSignInErrorMessage } from "./authErrors";

describe("mapSignInErrorMessage", () => {
  it("잘못된 로그인 정보 에러를 일반화된 문구로 바꾼다 (계정 존재 여부 노출 금지)", () => {
    expect(mapSignInErrorMessage("Invalid login credentials")).toBe(
      "이메일 또는 비밀번호가 올바르지 않아요."
    );
  });

  it("대소문자가 달라도 동일하게 처리한다", () => {
    expect(mapSignInErrorMessage("INVALID LOGIN CREDENTIALS")).toBe(
      "이메일 또는 비밀번호가 올바르지 않아요."
    );
  });

  it("존재하지 않는 사용자 에러도 동일한 일반화된 문구로 바꾼다", () => {
    expect(mapSignInErrorMessage("User not found")).toBe(
      "이메일 또는 비밀번호가 올바르지 않아요."
    );
  });

  it("이메일 미인증 에러는 별도 안내 문구를 보여준다", () => {
    expect(mapSignInErrorMessage("Email not confirmed")).toBe(
      "이메일 인증을 아직 완료하지 않았어요. 가입 시 받은 메일을 확인해주세요."
    );
  });

  it("rate limit 에러는 잠시 후 재시도 문구를 보여준다", () => {
    expect(mapSignInErrorMessage("Email rate limit exceeded")).toBe(
      "잠시 후 다시 시도해주세요."
    );
  });

  it("알 수 없는 에러는 일반적인 실패 문구로 fallback한다", () => {
    expect(mapSignInErrorMessage("Something unexpected happened")).toBe(
      "로그인에 실패했어요. 잠시 후 다시 시도해주세요."
    );
  });
});
