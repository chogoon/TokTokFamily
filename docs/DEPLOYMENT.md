# 배포 런북 (Supabase 호스팅 + backend 서버)

이 문서는 **Supabase 호스팅 프로젝트**와 **backend(Express) 서버**를 실제로 배포하는 절차다.
범위 밖: 앱스토어 제출(EAS Build, `eas.json`)과 frontend 코드 수정 — frontend는 로컬 Expo 개발
서버를 계속 쓰고, `.env`만 운영 Supabase/backend를 가리키도록 바꾼다(5번 참고).

사용자가 직접 해야 하는 작업(계정 가입/클릭/대시보드 조작)은 **[수동]**으로 표시했다.

---

## 0. 사전 준비

- Supabase CLI가 로그인되어 있어야 한다: `npx supabase login` **[수동]** (브라우저로 인증).
- 아래 절차는 저장소 루트(`/Users/chogoon/GoProjects/TokTokFamily`)에서 실행한다고 가정한다.

---

## 1. Supabase 호스팅 프로젝트 생성 + 마이그레이션 적용

### 1-1. 프로젝트 생성 **[수동]**

둘 중 하나:

- **대시보드**: https://supabase.com/dashboard 에서 "New project" → 리전은 한국 사용자 대상이면
  `Northeast Asia (Seoul)` 권장 → DB 비밀번호를 설정하고 기록해둔다(분실 시 대시보드에서 재설정 가능).
- **CLI**: `npx supabase projects create "family-toktok" --org-id <조직ID>` (조직 ID는
  `npx supabase orgs list`로 확인).

생성 후 프로젝트 ref(대시보드 URL의 `https://supabase.com/dashboard/project/<ref>` 부분, 20자
영숫자)를 기록해둔다.

### 1-2. 로컬 저장소를 원격 프로젝트에 link

```bash
npx supabase link --project-ref <ref>
```

DB 비밀번호를 물어보면 1-1에서 설정한 값을 입력한다. `supabase/config.toml`은 로컬 전용 설정만
담고 있으므로 이 명령으로 바뀌지 않는다 — link 정보는 `.gitignore`에 있는 `supabase/.temp/`에
로컬로만 저장된다.

### 1-3. 마이그레이션 전체 적용

```bash
npx supabase db push
```

`supabase/migrations/`의 아래 7개 파일이 **파일명(=타임스탬프) 순서대로** 적용된다:

1. `20261021140000_init.sql` — families/members/rooms/messages 등 전체 스키마 + RLS
2. `20261021150000_invites_and_bootstrap.sql` — 가족 생성/초대 RPC
3. `20261021160000_add_kid_bootstrap.sql` — 아이 추가 RPC
4. `20261022030000_enable_messages_realtime.sql` — messages를 Realtime publication에 등록
5. `20261022040000_enable_reactions_realtime.sql` — reactions를 Realtime publication에 등록
6. `20261022050000_add_qr_short_code.sql` — 숫자 코드 로그인용 컬럼
7. `20261022060000_add_push_webhook_triggers.sql` — **로컬 전용** push webhook 트리거.
   `supabase_functions` 스키마가 없는(아직 Database Webhooks를 켜지 않은) 운영 프로젝트에서는
   에러 없이 `RAISE NOTICE`만 남기고 트리거 생성을 건너뛴다 — `migration list`에는 적용됨으로
   표시되지만 실제 트리거는 생성되지 않는다. 운영 push 디스패치는 이 마이그레이션이 아니라
   바로 아래 2번 섹션의 대시보드 수동 설정으로 동작한다.

> **참고 (drift 점검 결과)**: 4번, 5번 마이그레이션은 과거 로컬 환경에서 `alter publication
> supabase_realtime add table ...`을 수동으로 먼저 실행해둔 뒤 마이그레이션 파일로 기록한 적이
> 있어, 로컬 `supabase_migrations.schema_migrations` 이력에 빠져 있는 drift가 있었다(실제 DB
> 상태와 이력 불일치). 이 상태를 로컬에서 재현해 같은 `alter publication` 문을 다시 실행해보니
> `ERROR: relation "messages" is already member of publication "supabase_realtime"`로
> 실패하는 것을 확인했다 — 운영 프로젝트에 처음 `db push`를 할 때는 이력이 비어 있으니 문제가
> 없지만, 추후 누군가 Studio UI 등으로 publication을 수동 조작하면 같은 방식으로 깨질 수
> 있었다. 두 마이그레이션 파일을 `pg_publication_tables`를 먼저 조회해 멤버가 아닐 때만
> `alter publication`을 실행하는 `do $$ ... $$` 블록으로 바꿔 **멱등화**했다 — 이제 이미 반영된
> 상태에서 다시 실행해도 에러 없이 통과한다(로컬에서 재실행해 확인함).

적용 후 확인:

```bash
npx supabase migration list --linked
```

로컬 이력과 원격 이력이 모두 7개로 일치해야 한다(7번 `20261022060000`도 "적용됨"으로 표시되지만,
위에서 설명했듯 실제 트리거는 생성되지 않는다 — 정상이다).

---

## 2. Supabase Database Webhook 생성 (메시지/칭찬 → 푸시 디스패치)

> 1번 섹션에서 적용한 `20261022060000_add_push_webhook_triggers.sql`은 **로컬 전용**이라 운영
> 프로젝트에는 트리거가 생기지 않는다. 운영에서 메시지/칭찬 insert 시 푸시가 나가게 하려면
> 아래 2-2 절차로 대시보드에서 Database Webhook을 직접 만들어야 한다 — 이 섹션을 건너뛰면
> 운영 backend가 떠 있어도 `/webhooks/push`가 전혀 호출되지 않는다.

backend의 `POST /webhooks/push`(`backend/src/routes/pushWebhook.ts`)가 받는 요청 형식:

- 바디: `{ "type": "INSERT" | "UPDATE" | "DELETE", "table": "<table>", "record": {...} }`
  (Supabase Database Webhook의 기본 페이로드 형식과 동일 — 별도 커스텀 바디 설정 필요 없음)
- 헤더: `x-webhook-secret: <PUSH_WEBHOOK_SECRET 값>`
  (`backend/src/middleware/verifyWebhookSecret.ts`가 이 헤더와 환경변수 `PUSH_WEBHOOK_SECRET`을
  정확히 일치시켜야만 통과시킨다. 대소문자는 HTTP 헤더 특성상 무관하지만 헤더 이름 철자가
  정확히 `x-webhook-secret`이어야 한다.)

### 2-1. backend를 먼저 배포한다

Database Webhook은 실제 호출 가능한 URL이 필요하므로, **3번(backend 배포)을 먼저 끝내고** 이
섹션으로 돌아온다. `PUSH_WEBHOOK_SECRET` 값은 3-2에서 생성한 것과 **동일한 값**을 아래 5번
"Headers"에 넣어야 한다.

### 2-2. Webhook 생성 **[수동]**

Supabase 대시보드 → 프로젝트 선택 → **Database → Webhooks → Create a new hook**.

`messages` insert용:

1. Name: `push-on-message-insert`
2. Table: `messages`
3. Events: `Insert`만 체크 (`Update`, `Delete`는 해제 — backend가 INSERT 외에는 `skipped: true`로
   무시하지만, 불필요한 호출을 줄이기 위해 처음부터 Insert만 등록)
4. Type: `HTTP Request`
5. Method: `POST`
6. URL: `https://<배포된 backend 도메인>/webhooks/push`
7. Headers: `Add new header` → Name `x-webhook-secret`, Value `<PUSH_WEBHOOK_SECRET 값>`
   (3-2에서 호스팅 플랫폼에 설정한 값과 정확히 같아야 한다)
8. HTTP Params / Timeout: 기본값 유지
9. **Create webhook**

`praises` insert용으로 동일하게 하나 더 만든다:

1. Name: `push-on-praise-insert`
2. Table: `praises`
3. Events: `Insert`만
4. URL/헤더: 위와 동일 (`https://<배포된 backend 도메인>/webhooks/push`, 같은
   `x-webhook-secret`)

> 주의: Supabase Webhook UI는 테이블당 하나의 hook에 여러 테이블을 묶을 수 없다 — 테이블마다
> 별도 hook을 만들어야 한다. 두 hook 모두 같은 backend 엔드포인트(`/webhooks/push`)를 가리키고,
> backend가 `record`의 테이블(`table` 필드)을 보고 `messages`/`praises`를 분기 처리한다.

---

## 3. backend 배포 (Railway 또는 Render)

`backend/Dockerfile`로 멀티스테이지 빌드를 준비해뒀다(`node:22-slim` 기반 — `@supabase/supabase-js`가
Node 22+를 요구). 로컬에서 실제로 `docker build -f backend/Dockerfile -t family-toktok-backend .`
로 빌드 성공, 컨테이너 실행 후 `curl http://localhost:<port>/health`가 `{"status":"ok"}`를
반환하는 것까지 확인했다.

**반드시 저장소 루트에서, `-f backend/Dockerfile`로 빌드할 것** — 모노레포 npm workspaces라
backend만의 디렉토리로는 루트 `package.json`(workspaces 선언)과 `package-lock.json`에 접근할 수
없어 의존성 설치가 안 된다. 루트의 `.dockerignore`가 `frontend/`, `flutter/`, `node_modules/` 등을
빌드 컨텍스트에서 제외하므로 전송 크기는 작게 유지된다.

### 3-1. 환경변수 값 확인 **[수동]**

Supabase 대시보드 → 프로젝트 → **Settings → API**에서:

- `SUPABASE_URL` ← "Project URL"
- `SUPABASE_ANON_KEY` ← "Project API keys"의 `anon` `public` 키
- `SUPABASE_SERVICE_ROLE_KEY` ← "Project API keys"의 `service_role` `secret` 키
  (절대 frontend/클라이언트에 노출하지 말 것 — backend 프로세스 환경변수로만 주입)

### 3-2. `PUSH_WEBHOOK_SECRET` 생성 **[수동]**

랜덤 문자열을 직접 만든다:

```bash
openssl rand -hex 32
```

이 값을 호스팅 플랫폼 환경변수와 2-2의 Webhook 헤더 양쪽에 **동일하게** 입력한다.

### 3-3-A. Railway에 배포 **[수동]**

1. https://railway.com 가입/로그인 → **New Project → Deploy from GitHub repo** →
   `chogoon/TokTokFamily` 선택.
2. 루트에 `railway.json`을 준비해뒀다(Dockerfile 빌더 지정, `dockerfilePath: backend/Dockerfile`,
   헬스체크 `/health`). Railway가 레포를 인식하면 이 설정을 자동으로 읽어 Dockerfile 빌드로
   진행한다 — 별도 설정 없이 "Deploy"만 누르면 된다.
3. 서비스 생성 후 **Variables** 탭에서 3-1/3-2의 값 + `CORS_ORIGIN`(비워두면 전체 허용, 운영
   프론트 도메인이 생기면 좁힐 것) + `PORT`(Railway가 자동 주입하는 `PORT`를 쓰거나 `4000`으로
   고정 — `backend/src/index.ts`가 `process.env.PORT`를 그대로 읽으므로 Railway의 자동 할당
   포트와 자연히 맞물린다)를 등록.
4. **Settings → Networking → Generate Domain**으로 공개 도메인을 발급받는다. 이 도메인이
   2-2에서 쓸 `<배포된 backend 도메인>`이다.

### 3-3-B. Render에 배포 **[수동, 3-3-A 대신 택1]**

1. https://render.com 가입/로그인.
2. **New → Blueprint** → `chogoon/TokTokFamily` 연결 → 루트의 `render.yaml`을 자동 인식
   (`runtime: docker`, `dockerfilePath: ./backend/Dockerfile`, `dockerContext: .`,
   `healthCheckPath: /health`).
   - Blueprint를 쓰지 않고 수동으로 하려면: **New → Web Service** → 레포 연결 → Runtime을
     `Docker`로 선택 → Dockerfile Path `backend/Dockerfile`, Docker Build Context Directory
     `.`(루트) 입력.
3. 생성 과정에서 `sync: false`로 표시된 환경변수(`SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY`, `PUSH_WEBHOOK_SECRET`, `CORS_ORIGIN`)를 **Environment** 탭에서
   직접 채운다(Blueprint가 값까지 자동으로 채워주지 않는다, 민감값이라 코드에 넣지 않았다).
4. 배포 완료 후 서비스 상세 페이지에 표시되는 `https://<서비스명>.onrender.com` 도메인을
   기록한다.

---

## 4. 배포 후 확인

### 4-1. 헬스체크

```bash
curl https://<backend-domain>/health
# {"status":"ok"} 가 나오면 정상
```

### 4-2. 스모크 테스트 (가족 생성 API)

`POST /families`는 `verifyJwt` 미들웨어로 보호되어 있어 실제 Supabase Auth 사용자의 access
token이 필요하다. 가장 간단한 방법:

1. Supabase 대시보드 → **Authentication → Users → Add user**로 테스트 보호자 계정을 하나
   만든다(이메일/비밀번호 임시 지정). **[수동]**
2. 해당 계정으로 로그인해 access token을 받는다(예: `curl`로 Supabase Auth의 password grant
   엔드포인트 호출):

```bash
curl -s -X POST "https://<project-ref>.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"email":"<테스트이메일>","password":"<테스트비밀번호>"}' \
  | tee /tmp/auth.json
```

3. 받은 `access_token`으로 가족 생성을 호출한다:

```bash
TOKEN=$(node -e "console.log(require('/tmp/auth.json').access_token)")
curl -s -X POST "https://<backend-domain>/families" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"familyName":"테스트가족","parentName":"테스트보호자"}'
```

`201`과 `{"familyId": "...", "memberId": "..."}`가 돌아오면 backend ↔ Supabase 연결과
service-role 권한까지 정상 동작하는 것이다. 테스트가 끝나면 1단계에서 만든 테스트 사용자를
대시보드에서 삭제해 정리한다.

### 4-3. 푸시 웹훅 확인 (선택)

실제 메시지를 보내거나, 2-2에서 만든 Webhook의 "Logs" 탭에서 호출 결과(2xx)를 확인한다.
Expo 푸시 토큰이 없는 테스트 계정이면 `recipientsForMessage`가 빈 배열을 반환해 실질적인 푸시는
가지 않지만, `/webhooks/push`가 200을 반환하는지만 봐도 연결 확인은 충분하다.

---

## 5. frontend가 운영 backend/Supabase를 보도록 전환 (로컬 Expo 개발 서버 유지)

**앱스토어 빌드(EAS)는 이번 범위가 아니다** — 아래는 로컬 `npx expo start`로 띄운 개발 서버가
운영 backend/Supabase를 가리키게만 하는 절차다.

1. `frontend/.env.example`을 참고해 `frontend/.env`를 만들거나 기존 파일을 연다.
2. 아래 값을 운영 값으로 교체:

```bash
EXPO_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=<3-1에서 확인한 anon key>
EXPO_PUBLIC_BACKEND_URL=https://<backend-domain>
```

3. Expo 개발 서버를 재시작한다(`npm run start --workspace=frontend` 등 — 환경변수는 서버
   재시작 시점에 로드되므로 값을 바꾼 뒤 반드시 재시작).
4. 웹 브라우저로 접속하는 경우 CORS_ORIGIN을 해당 origin으로 좁혀뒀다면 그 도메인에서만
   backend 호출이 성공한다 — 로컬 Expo 웹(`http://localhost:8081` 등)에서 테스트할 때는
   `CORS_ORIGIN`에 그 origin을 추가하거나, 당분간 비워서 전체 허용 상태로 둔다.
5. 네이티브 기기(Expo Go)로 테스트하는 경우 CORS 제약이 없으므로 `CORS_ORIGIN` 설정과 무관하게
   동작한다.

로컬 개발용 Supabase로 되돌리려면 `frontend/.env`의 값을 다시 로컬 Supabase 값
(`http://127.0.0.1:54321` 등, `run-dev-stack` 스킬 참고)으로 바꾸고 서버를 재시작한다.
