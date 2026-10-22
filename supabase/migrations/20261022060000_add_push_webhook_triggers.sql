-- messages/praises에 INSERT가 생기면 backend의 POST /webhooks/push를 호출하는
-- Database Webhook(트리거)을 건다.
--
-- backend/src/routes/pushWebhook.ts는 이미 완성되어 있었지만, 이 트리거가 로컬/운영
-- 어디에도 연결되어 있지 않아 실제로 호출된 적이 없었다 — 그래서 메시지/칭찬을
-- 보내도 푸시 알림이 전혀 오지 않는 버그가 있었다(코드 문제가 아니라 설정 누락).
--
-- supabase_functions.http_request는 Supabase CLI가 기본 제공하는 트리거 함수로,
-- pg_net을 통해 (type, table, schema, record, old_record) 형태의 JSON을 POST로
-- 보낸다 — 이는 pushWebhook.ts가 zod로 검증하는 페이로드 형태와 정확히 일치한다.
--
-- URL/시크릿은 로컬 개발 기준값이다. 로컬 Supabase는 Docker 컨테이너에서 돌기
-- 때문에 backend(호스트에서 실행)를 가리키려면 localhost가 아니라
-- host.docker.internal을 써야 한다. 운영 배포 시에는 이 트리거를 실제 backend
-- 공개 URL과 운영 PUSH_WEBHOOK_SECRET으로 재생성해야 한다(docs/DEPLOYMENT.md 참조) —
-- 예: `alter trigger ... `가 아니라 drop/create로 교체(트리거 인자는 변경 불가).
--
-- IF NOT EXISTS 가드가 없는 이유: trigger는 `create or replace`가 없고, 이미 있는
-- 트리거에 `create trigger`를 다시 실행하면 "already exists" 에러가 난다. 그래서
-- drop ... if exists로 먼저 지우고 다시 만드는 방식으로 재실행 가능하게(idempotent)
-- 만든다.

drop trigger if exists push_webhook_messages on public.messages;
create trigger push_webhook_messages
after insert on public.messages
for each row execute function supabase_functions.http_request(
  'http://host.docker.internal:4000/webhooks/push',
  'POST',
  '{"Content-Type":"application/json","x-webhook-secret":"local-dev-secret"}',
  '{}',
  '5000'
);

drop trigger if exists push_webhook_praises on public.praises;
create trigger push_webhook_praises
after insert on public.praises
for each row execute function supabase_functions.http_request(
  'http://host.docker.internal:4000/webhooks/push',
  'POST',
  '{"Content-Type":"application/json","x-webhook-secret":"local-dev-secret"}',
  '{}',
  '5000'
);
