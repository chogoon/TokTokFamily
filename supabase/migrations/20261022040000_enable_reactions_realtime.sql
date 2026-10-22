-- reactions를 supabase_realtime publication에 추가한다.
--
-- frontend/services/rooms.ts의 subscribeToReactions가 postgres_changes로 변경을
-- 구독하지만, 이 publication에 테이블이 등록되어 있지 않으면 Realtime 서버가
-- 변경 이벤트를 전혀 브로드캐스트하지 않는다 — 그 결과 상대가 누른 반응이 내
-- 화면에 즉시 반영되지 않고, 화면을 새로고침(재조회)해야만 보이는 버그가 났다.
-- messages 테이블에 있었던 동일한 문제를 20261022030000 마이그레이션에서
-- 해결한 것과 같은 방식이다.

alter publication supabase_realtime add table public.reactions;
