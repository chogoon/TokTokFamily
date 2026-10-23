-- [로컬 전용] messages/praises에 INSERT가 생기면 backend의 POST /webhooks/push를
-- 호출하는 Database Webhook(트리거)을 로컬 Supabase에만 건다.
--
-- backend/src/routes/pushWebhook.ts는 이미 완성되어 있었지만, 이 트리거가 로컬/운영
-- 어디에도 연결되어 있지 않아 실제로 호출된 적이 없었다 — 그래서 메시지/칭찬을
-- 보내도 푸시 알림이 전혀 오지 않는 버그가 있었다(코드 문제가 아니라 설정 누락).
--
-- supabase_functions.http_request는 Supabase CLI가 띄우는 로컬 환경에는 기본
-- 제공되는 트리거 함수로, pg_net을 통해 (type, table, schema, record, old_record)
-- 형태의 JSON을 POST로 보낸다 — 이는 pushWebhook.ts가 zod로 검증하는 페이로드
-- 형태와 정확히 일치한다.
--
-- 하지만 호스팅된(운영) Supabase 프로젝트에는 `supabase_functions` 스키마가 기본
-- 생성되어 있지 않다 — 대시보드에서 "Database → Webhooks" 기능을 최소 한 번 켜야
-- 생긴다. 게다가 이 파일의 URL/시크릿(`http://host.docker.internal:4000/...`,
-- `local-dev-secret`)은 로컬 Docker 컨테이너에서 호스트의 backend를 가리키기 위한
-- 로컬 전용 값이라, 운영 backend 공개 URL과도 다르고, 운영 시크릿을 평문으로 git에
-- 커밋해서도 안 된다. 그래서 이 마이그레이션은 설계상 **로컬 전용**이다:
--
--   - `supabase_functions` 스키마가 있으면(로컬 Supabase) 기존과 동일하게 트리거
--     2개(push_webhook_messages, push_webhook_praises)를 drop/create로 재생성한다.
--   - 스키마가 없으면(아직 Database Webhooks를 활성화하지 않은 운영 프로젝트)
--     에러를 내지 않고 RAISE NOTICE만 남긴 뒤 트리거 생성을 조용히 건너뛴다 —
--     `supabase db push`가 운영에서 실패하지 않게 하기 위함이다.
--
-- 운영 환경의 실제 webhook 설정(대시보드에서 수동으로 Database Webhook을 만들고
-- 운영 backend URL + 안전하게 생성한 PUSH_WEBHOOK_SECRET을 쓰는 절차)은
-- `docs/DEPLOYMENT.md`의 "2. Supabase Database Webhook 생성" 섹션을 참조한다.
-- 이 마이그레이션의 트리거를 운영에 그대로 적용하면 안 되며, 운영은 항상 대시보드
-- Webhook UI로만 설정한다.
--
-- IF NOT EXISTS 가드가 없는 이유(트리거 자체에 대해): trigger는 `create or
-- replace`가 없고, 이미 있는 트리거에 `create trigger`를 다시 실행하면 "already
-- exists" 에러가 난다. 그래서 drop ... if exists로 먼저 지우고 다시 만드는 방식으로
-- 재실행 가능하게(idempotent) 만든다 — 이는 `supabase_functions` 스키마가 있는
-- 분기 안에서만 적용된다.

do $$
begin
  if exists (
    select 1
    from information_schema.schemata
    where schema_name = 'supabase_functions'
  ) then
    execute $trigger$
      drop trigger if exists push_webhook_messages on public.messages
    $trigger$;
    execute $trigger$
      create trigger push_webhook_messages
      after insert on public.messages
      for each row execute function supabase_functions.http_request(
        'http://host.docker.internal:4000/webhooks/push',
        'POST',
        '{"Content-Type":"application/json","x-webhook-secret":"local-dev-secret"}',
        '{}',
        '5000'
      )
    $trigger$;

    execute $trigger$
      drop trigger if exists push_webhook_praises on public.praises
    $trigger$;
    execute $trigger$
      create trigger push_webhook_praises
      after insert on public.praises
      for each row execute function supabase_functions.http_request(
        'http://host.docker.internal:4000/webhooks/push',
        'POST',
        '{"Content-Type":"application/json","x-webhook-secret":"local-dev-secret"}',
        '{}',
        '5000'
      )
    $trigger$;
  else
    raise notice '[20261022060000] supabase_functions 스키마가 없어 push_webhook_messages/push_webhook_praises 트리거 생성을 건너뜁니다. 이는 호스팅된(운영) Supabase 프로젝트에서 Database → Webhooks 기능을 아직 활성화하지 않았을 때 정상입니다. 운영 환경에서는 이 트리거를 쓰지 말고, Supabase 대시보드에서 Database Webhook을 직접 만들어 실제 backend URL과 안전하게 생성한 시크릿(PUSH_WEBHOOK_SECRET)을 쓰세요 — 절차는 docs/DEPLOYMENT.md의 "2. Supabase Database Webhook 생성" 섹션을 참조하세요.';
  end if;
end
$$;
