---
name: run-dev-stack
description: 로컬 Supabase + backend + frontend(Expo) 개발 스택을 띄우고 상태를 확인한다. "개발 서버 띄워줘", "로컬에서 확인해줘", "Supabase 켜줘" 같은 요청에 사용한다.
---

# 로컬 개발 스택 실행

Family TokTok은 세 부분으로 뜬다: 로컬 Supabase(Docker), `backend`(Express), `frontend`(Expo). 매번 같은 순서로 띄우고 상태를 확인해야 하므로 이 스킬로 고정한다.

## 전제 조건

- Docker Desktop이 실행 중이어야 한다. `docker info`로 먼저 확인한다. daemon이 꺼져 있으면 사용자에게 Docker Desktop을 켜달라고 요청하고 대기한다 — 대신 켜줄 수 없다.
- 저장소 루트(`package.json`의 `workspaces` 필드가 있는 디렉토리)에서 작업한다.

## 순서

1. **Supabase 상태 확인**

   ```bash
   npx supabase status
   ```

   `API_URL`이 응답하면 이미 떠 있다. 안 떠 있으면(`Stopped services` 또는 에러):

   ```bash
   npx supabase start
   ```

   첫 실행은 Docker 이미지를 받느라 수 분 걸릴 수 있다 — 백그라운드로 돌리고 기다린다. 일부 서비스만 뜨고 멈추면(`supabase status`에 `Stopped services` 일부 남음) `npx supabase stop` 후 `npx supabase start`를 한 번 더 돌린다 (알려진 flake).

2. **backend 기동**

   `backend/.env` 파일이 없으면 `npx supabase status`의 `API_URL`/`ANON_KEY`/`SERVICE_ROLE_KEY`를 `backend/.env.example` 형식에 맞춰 채워 `backend/.env`로 만든다 (`.env`는 git에 커밋하지 않는다 — `.gitignore` 확인).

   ```bash
   npm run dev --workspace=backend
   ```

   백그라운드로 띄우고 `GET http://localhost:4000/health`가 `{"status":"ok"}`를 반환하는지 확인한다.

3. **frontend 기동**

   `frontend/.env` 파일이 없으면 `EXPO_PUBLIC_SUPABASE_URL`/`EXPO_PUBLIC_SUPABASE_ANON_KEY`(Supabase 로컬 값)와 `EXPO_PUBLIC_BACKEND_URL=http://localhost:4000`을 `frontend/.env.example` 형식으로 채워 `frontend/.env`로 만든다.

   ```bash
   npm run web --workspace=frontend
   ```

   웹으로 먼저 띄워 빠르게 화면을 확인한다. `frontend/package.json`의 `web`/`start`/`ios`/`android` 스크립트는 모두 `EXPO_USE_METRO_WORKSPACE_ROOT=1`을 포함한다 — 이 환경변수 없이 `npx expo start`를 직접 실행하면 npm workspaces 호이스팅 때문에 번들 URL에 `/../`가 섞여 브라우저에서 404가 난다(알려진 이슈, `frontend/metro.config.js`의 주석 참고). iOS/Android 시뮬레이터 확인이 필요하면 사용자에게 명시적으로 요청받았을 때만 `npm run ios`/`npm run android`로 전환한다.

   웹에서 backend를 호출하는 화면(가족 생성, 초대, QR 로그인)을 테스트할 때는 CORS가 걸리므로 backend가 `cors` 미들웨어로 응답하는지 확인한다(`backend/src/app.ts`) — 네이티브 앱 빌드에서는 이 제약이 없다.

## 정리

작업이 끝나면 백그라운드 프로세스(backend, expo)를 종료한다. Supabase는 다음 세션에서도 쓸 일이 많으므로, 사용자가 명시적으로 요청하지 않으면 `npx supabase stop`을 실행하지 않는다 — 단, `.claude/settings.json`의 Stop 훅이 `npm run test`를 돌리므로 backend 통합 테스트가 통과하려면 Supabase가 계속 떠 있어야 한다는 점을 기억한다.

## 데이터 리셋이 필요할 때

마이그레이션을 수정했거나 테스트 데이터를 치워야 할 때:

```bash
npx supabase db reset
```

이 명령은 로컬 DB를 지우고 `supabase/migrations/`를 순서대로 재적용한다. 운영 DB에는 영향 없음(로컬 전용).
