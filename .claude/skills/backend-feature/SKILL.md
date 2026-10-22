---
name: backend-feature
description: backend/ 라우트나 supabase/ 마이그레이션·RLS 기능을 backend-dev 에이전트에게 위임해서 구현한다. "가족 초대 API 만들어줘", "이 테이블에 RLS 추가해줘", "푸시 로직 고쳐줘" 같이 백엔드/DB 작업만 필요할 때 사용한다.
---

# 백엔드 기능 구현 위임

이 스킬은 `backend/`, `supabase/` 범위의 구현 요청을 `.claude/agents/backend-dev.md`에 정의된 `backend-dev` 에이전트에게 위임하는 고정 절차다.

## 절차

1. 요청이 ADR-004의 backend 범위(가족 생성/초대/아이 추가, QR 로그인, 푸시 디스패치) 안에 있는지 먼저 확인한다. 범위 밖(일상 대화/기분/칭찬 데이터)이면 frontend가 Supabase를 직접 호출해야 한다는 점을 사용자에게 먼저 설명하고 확인받는다.
2. 로컬 Supabase가 떠 있는지 `npx supabase status`로 확인한다. 꺼져 있으면 `run-dev-stack` 스킬 절차로 띄운다.
3. `backend-dev` 에이전트를 호출한다. 프롬프트에는 다음을 명시한다:
   - 구현할 라우트/마이그레이션과 수용 기준.
   - 관련 기존 코드/마이그레이션 경로.
   - TDD 요구: 테스트를 먼저 쓰고(`*.integration.test.ts`는 로컬 Supabase 필요), authorization 검증과 service-role 키 비노출을 반드시 확인.
4. 에이전트가 끝나면 `npm run build --workspace=backend && npm run lint --workspace=backend && npm test --workspace=backend`가 실제로 통과했는지 결과를 확인한다.
5. 스키마를 변경했으면 `npx supabase db reset` 후 RLS가 의도대로 동작하는지(다른 가족/형제 차단) 실제 질의로 검증했는지 확인한다.
6. 커밋/푸시는 이 스킬의 범위가 아니다 — 사용자가 원하면 `commit-and-push` 스킬을 호출한다.
