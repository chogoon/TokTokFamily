-- messages를 supabase_realtime publication에 추가한다.
--
-- frontend/services/rooms.ts의 subscribeToMessages가 postgres_changes로 INSERT를
-- 구독하지만, 이 publication에 테이블이 등록되어 있지 않으면 Realtime 서버가
-- 변경 이벤트를 전혀 브로드캐스트하지 않는다 — 그 결과 메시지를 보내도 상대
-- 화면에 즉시 반영되지 않고, 화면을 새로고침(재조회)해야만 보이는 버그가 났다.
-- 기분/칭찬판 등 다른 테이블은 해당 화면이 Realtime 구독을 실제로 쓰게 될 때
-- 같은 방식으로 추가한다.
--
-- IF NOT EXISTS 가드: "alter publication ... add table"은 이미 멤버인 테이블에
-- 다시 실행하면 "already member of publication" 에러로 실패한다(멱등하지 않음).
-- 과거에 이 테이블을 Studio UI 등으로 수동으로 publication에 추가한 뒤 이 마이그
-- 레이션이 기록 없이 실제로는 반영된 상태(drift)가 로컬에서 재현된 적이 있어,
-- 운영 프로젝트에 `supabase db push`를 적용할 때도 같은 이유로 실패할 수 있다.
-- 아래처럼 현재 publication 멤버십을 먼저 확인해 가드한다.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end
$$;
