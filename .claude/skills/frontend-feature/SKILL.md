---
name: frontend-feature
description: frontend/ 안의 화면·컴포넌트·라우팅 기능을 frontend-dev 에이전트에게 위임해서 구현한다. "로그인 화면 만들어줘", "대화 탭 구현해줘", "이 화면 디자인 고쳐줘" 같이 프론트 작업만 필요할 때 사용한다.
---

# 프론트 기능 구현 위임

이 스킬은 `frontend/` 범위의 구현 요청을 `.claude/agents/frontend-dev.md`에 정의된 `frontend-dev` 에이전트에게 위임하는 고정 절차다.

## 절차

1. 요청이 정말 frontend 전용인지 확인한다. 새 backend 라우트나 Supabase 마이그레이션이 필요하면 이 스킬 대신 `backend-feature` 스킬(또는 둘 다 순서대로)을 쓴다.
2. `frontend-dev` 에이전트를 호출한다. 프롬프트에는 다음을 명시한다:
   - 구현할 화면/기능과 수용 기준(어떤 동작이 되어야 하는지).
   - 관련 기존 파일 경로(있다면).
   - TDD 요구: 순수 로직은 테스트를 먼저 쓰고, Supabase/backend 연동은 `run-dev-stack`으로 실제 확인.
3. 에이전트가 끝나면 `npm run build --workspace=frontend && npm run lint --workspace=frontend && npm test --workspace=frontend`가 실제로 통과했는지 결과를 확인한다.
4. 화면 변경이면 `run-dev-stack` 스킬로 Expo 웹을 띄워 실제로 확인했는지(또는 Playwright 스크린샷) 확인한다.
5. 구현이 끝나고 검증까지 통과하면, 커밋/푸시가 필요한지 사용자에게 묻지 않고 바로 다음 단계로 넘어가지 말 것 — 커밋은 `commit-and-push` 스킬(`git-ops` 에이전트)이 전담하므로, 사용자가 커밋을 원하면 그 스킬을 호출한다.
