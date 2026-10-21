# 프로젝트: Family TokTok (우리가족 톡톡)

초등학생 자녀와 부모만 쓰는, 가족 전용 대화 앱. 현재 상태: 웹 프로토타입(`family-sns.html`)만 존재, 앱 개발 미시작.

## 기술 스택

- npm workspaces 모노레포: `frontend/`, `backend/`
- React Native + Expo (iOS/Android 동시 대응) — `frontend/`
- Node.js + Express + TypeScript (`backend/` — 가족 생성/초대, QR 로그인, 푸시 디스패치 전용)
- TypeScript strict mode
- Supabase (Auth, Postgres, Realtime, Storage)
- Expo Notifications (FCM / APNs)

## 아키텍처 규칙

- CRITICAL: frontend → Supabase 직접 접근 경로(대화/기분/칭찬 등 일상 데이터)는 반드시 Supabase RLS(행 단위 보안)를 거쳐야 한다. 클라이언트에서 family_id 필터링을 자체 구현해 RLS를 대체하지 말 것.
- CRITICAL: backend가 Service Role 키로 수행하는 작업(가족 생성, 초대 redeem, QR 토큰 발급/교환, 푸시 디스패치)은 RLS를 우회하므로 backend 코드가 family_id/role 기반 authorization을 스스로 명시적으로 검증해야 한다. Service Role 키는 backend 프로세스 밖으로 절대 유출하지 않는다(frontend에 내려주지 않음, 로그에 남기지 않음). 가능한 경우 backend는 사용자 JWT를 Supabase에 passthrough해 RLS가 계속 적용되게 하고, service role은 위 세 작업에만 한정한다.
- CRITICAL: 1:1 방(`rooms.type=kid`)은 해당 아이와 보호자만 읽고 쓸 수 있다. 형제가 다른 아이의 1:1 방이나 `moods.note`, `praise_boards`에 접근하는 경로를 만들지 말 것.
- CRITICAL: 친구 추가, 공개 프로필, 외부 공유, 좋아요 순위, 형제 비교 화면은 어떤 형태로도 구현하지 말 것 (`Family-TokTok-프로젝트-기획서.md` 2장 핵심 원칙 참조).
- 아이 계정은 이메일/비밀번호 없이 부모 폰의 QR을 찍어 기기 연결(QR 토큰은 일정 시간 후 만료)로 로그인한다.
- `frontend/`: 화면/컴포넌트는 `app/`, `components/`에, 타입은 `types/`에, Supabase 클라이언트·쿼리와 backend REST 호출은 `services/`에 분리한다.
- `backend/`: 라우트는 `src/routes/`, Supabase service-role 클라이언트와 Expo Push 래퍼는 `src/lib/`, 인증/검증 미들웨어는 `src/middleware/`에 분리한다.
- Supabase migrations/RLS 정책은 저장소 루트의 `supabase/`에 둔다 (frontend/backend가 공유하는 계약이므로 어느 한쪽 소유로 두지 않음).

## 개발 프로세스

- CRITICAL: 새 기능 구현 시 반드시 테스트를 먼저 작성하고, 테스트가 통과하는 구현을 작성할 것 (TDD)
- 커밋 메시지는 conventional commits 형식을 따를 것 (feat:, fix:, docs:, refactor:)
- 아이에게는 이름(별명)과 캐릭터 외의 개인정보(전화번호, 이메일, 생년월일, 학교)를 요구하는 필드를 추가하지 말 것

## 명령어

```bash
npm install                             # 루트에서 전체 workspace 설치
npx supabase start                      # 로컬 Supabase 스택 기동 (backend 테스트 전 필수, Docker 필요)
npm run dev --workspace=backend         # backend 개발 서버
npx expo start                          # frontend 개발 서버 (frontend/ 안에서)
npm run lint                            # 루트 — 두 workspace lint fan-out
npm run build                           # 루트 — 두 workspace build fan-out
npm run test                            # 루트 — 두 workspace test fan-out
```

- CRITICAL: `backend`의 통합 테스트(`*.integration.test.ts`)는 로컬 Supabase(`npx supabase start`, Docker 필요)가 실행 중이어야 통과한다. `npm run test`를 실행하기 전에 `npx supabase status`로 떠 있는지 확인할 것. 꺼져 있으면 테스트가 실패하는 게 아니라 `beforeAll`에서 명시적으로 에러를 던진다(원인 파악용).
