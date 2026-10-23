---
name: project-review
description: 변경 사항을 project-reviewer 에이전트에게 위임해서 이 프로젝트의 CRITICAL 규칙·RLS·ADR-004 역할 분리 기준으로 리뷰한다. "리뷰해줘", "이거 머지해도 될까", "커밋 전에 검토해줘" 같은 요청에 사용한다.
---

# 프로젝트 리뷰 위임

이 스킬은 변경 사항 검토를 `.claude/agents/project-reviewer.md`에 정의된 `project-reviewer` 에이전트(읽기 전용)에게 위임하는 고정 절차다.

## 절차

1. 리뷰 범위를 정한다 — 특정 커밋, `git diff`(unstaged+staged), 또는 특정 브랜치 전체인지 사용자 요청에서 확인한다. 모호하면 기본값은 "아직 커밋되지 않은 현재 변경 사항"이다.
2. `project-reviewer` 에이전트를 호출한다. 프롬프트에 리뷰 범위(커밋 해시/브랜치명/diff 대상)를 명시한다.
3. 에이전트의 체크리스트 결과표(CRITICAL 규칙 / RLS·권한 / 아키텍처 준수 / 테스트 존재 / 빌드 가능)를 그대로 사용자에게 전달한다 — 임의로 요약해서 ✅ 항목을 누락하지 않는다.
4. ❌ 항목이 있으면, 수정은 이 스킬이 직접 하지 않고 관련 workspace를 담당하는 `frontend-feature`/`backend-feature` 스킬(해당 에이전트)에게 넘기도록 제안한다.
5. 리뷰 결과 모두 ✅이고 사용자가 커밋/푸시를 원하면 `commit-and-push` 스킬을 호출하도록 안내한다 — 이 스킬 자체는 git 작업을 하지 않는다.
