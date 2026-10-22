-- messages를 supabase_realtime publication에 추가한다.
--
-- frontend/services/rooms.ts의 subscribeToMessages가 postgres_changes로 INSERT를
-- 구독하지만, 이 publication에 테이블이 등록되어 있지 않으면 Realtime 서버가
-- 변경 이벤트를 전혀 브로드캐스트하지 않는다 — 그 결과 메시지를 보내도 상대
-- 화면에 즉시 반영되지 않고, 화면을 새로고침(재조회)해야만 보이는 버그가 났다.
-- 기분/칭찬판 등 다른 테이블은 해당 화면이 Realtime 구독을 실제로 쓰게 될 때
-- 같은 방식으로 추가한다.

alter publication supabase_realtime add table public.messages;
