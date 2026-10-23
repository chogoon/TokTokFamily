-- Flutter 클라이언트는 Expo 생태계가 아니라 FCM(Firebase Cloud Messaging) 네이티브
-- 토큰을 발급받는다. backend가 push_token의 발급처(provider)를 구분해서 Expo Push API
-- 또는 Firebase Admin SDK 중 올바른 쪽으로 발송할 수 있도록 devices 테이블에
-- provider 컬럼을 추가한다.
--
-- 기존 행(RN 클라이언트가 등록한 것)은 전부 Expo 토큰이므로 default 'expo'로
-- 하위호환을 유지한다. RLS 정책은 전부 member_id = current_member_id() 기준이라
-- 컬럼 추가만으로는 영향이 없다(정책 재작성 불필요).

alter table public.devices
  add column provider text not null default 'expo' check (provider in ('expo', 'fcm'));
