-- 카메라 없이 숫자 코드를 직접 입력해 로그인하는 기능을 위해
-- qr_login_tokens에 short_code 컬럼을 추가한다.
--
-- nullable인 이유: QR 전용으로 발급된 과거 행(이 마이그레이션 이전 발급분)은
-- short_code가 없을 수 있다.
--
-- 부분 unique 인덱스로 "미사용(used_at is null)" short_code만 유일성을
-- 강제한다. 이미 redeem되어 used_at이 찍힌 행은 제약에서 빠지므로, 시간이
-- 지나 숫자 6자리(최대 100만 조합)가 소진되지 않고 재사용될 수 있다.
--
-- 참고: Postgres 부분 인덱스 조건은 now() 같은 비고정 함수를 쓸 수 없어
-- expires_at을 조건에 넣을 수 없다. 즉 이 인덱스 자체는 만료 여부를 보지
-- 않는다 — 발급 시점에 "같은 코드를 쓰는 다른 미사용 토큰이 없는지"만
-- 보장한다. 만료는 애플리케이션 코드(/code/redeem, /qr/redeem)가 매번
-- expires_at을 직접 비교해 걸러낸다.

alter table public.qr_login_tokens add column short_code text;

create unique index qr_login_tokens_short_code_active_idx
  on public.qr_login_tokens (short_code)
  where used_at is null and short_code is not null;
