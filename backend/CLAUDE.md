# backend/ 규칙

루트 `CLAUDE.md`의 공통 규칙에 더해 아래를 따른다. 대화에서는 이 workspace를 "백엔드"라고 부른다.

## 기술 스택

- Node.js + Express + TypeScript
- `@supabase/supabase-js` (service-role 클라이언트), `zod`(요청 검증), `expo-server-sdk`(푸시)
- 테스트: Vitest + supertest, ORM 없이 Supabase migrations를 스키마 단일 소스로 사용

## 역할 범위 (ADR-004)

backend는 아래 세 가지 작업만 담당한다. 그 외 일상 데이터(대화/기분/칭찬 등)는 frontend가 Supabase를 직접 호출하므로 backend에 새 라우트를 추가하지 않는다.

1. 가족 생성 + 최초 보호자 멤버십 부트스트랩, 초대 코드 발급/redeem
2. 아이 QR 로그인 토큰 발급/교환
3. 푸시 알림 디스패치 (Supabase Database Webhook 수신 → Expo Push API)

## 아키텍처 규칙

- CRITICAL: backend가 Service Role 키로 수행하는 작업은 RLS를 우회하므로, backend 코드가 family_id/role 기반 authorization을 스스로 명시적으로 검증해야 한다. Service Role 키는 backend 프로세스 밖으로 절대 유출하지 않는다(frontend에 내려주지 않음, 로그에 남기지 않음).
- 가능한 경우 사용자 JWT를 Supabase에 passthrough해 RLS가 계속 적용되게 한다. service role은 위 세 작업에만 한정한다.
- JWT 검증은 `src/middleware/verifyJwt.ts`에서 `admin.auth.getUser(token)`으로 Supabase Auth 서버에 위임한다. JWKS/서명 알고리즘(ES256)을 직접 파싱/검증하지 말 것 — Supabase가 버전업 시 키 로테이션/알고리즘을 바꿔도 깨지지 않는다.
- 아이 Auth 계정은 `kid-<member_id>@internal.familytoktok.local` 형태의 합성 이메일로만 존재한다(`src/lib/kidAuthUser.ts`). 이 이메일은 UI에 노출하거나 실제 메일 발송 대상으로 쓰지 않는다.
- 라우트는 `src/routes/`, Supabase 클라이언트/외부 API 래퍼는 `src/lib/`, 인증/검증 미들웨어는 `src/middleware/`에 분리한다.

## 테스트

- CRITICAL: `*.integration.test.ts`는 로컬 Supabase(`npx supabase start`, Docker 필요)가 실행 중이어야 통과한다. `npm run test --workspace=backend`를 실행하기 전에 `npx supabase status`(저장소 루트에서)로 떠 있는지 확인할 것. 꺼져 있으면 `beforeAll`에서 명시적으로 에러를 던진다.
- 외부 API 호출(Expo Push)이 섞인 라우트는 `vi.mock`으로 해당 함수를 모킹해 로컬 Supabase 없이도 돌 수 있게 한다 (`pushWebhook.test.ts` 참고).

## 명령어

```bash
npm run dev --workspace=backend    # 개발 서버 (저장소 루트에서)
npm run build --workspace=backend
npm run test --workspace=backend   # 로컬 Supabase 필요
npm run lint --workspace=backend
```
