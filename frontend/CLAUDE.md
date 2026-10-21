# frontend/ 규칙

루트 `CLAUDE.md`의 공통 규칙에 더해 아래를 따른다. 대화에서는 이 workspace를 "프론트"라고 부른다.

## 기술 스택

- React Native + Expo (Expo Router), iOS/Android 동시 대응
- `@supabase/supabase-js` (anon 클라이언트)
- 테스트: Jest (`jest-expo` preset)

## 디렉토리 구조

- 화면/라우트는 `app/`에 Expo Router 파일 기반 라우팅으로 둔다. `app/(auth)/`는 가족 생성/초대/QR 로그인, `app/(tabs)/`는 대화/기분/칭찬/가족 탭.
- 재사용 UI 컴포넌트는 `components/`, 타입은 `types/`, 날짜 포맷·QR 파싱 등 순수 유틸은 `lib/`, 인증 컨텍스트는 `contexts/`.
- Supabase 직접 호출과 backend REST 호출은 모두 `services/`에 모은다. 화면 컴포넌트가 `services/`를 거치지 않고 `@supabase/supabase-js`나 `fetch`를 직접 호출하지 않는다.

## 패턴 (ADR-004 기준 — 두 가지 경로가 다르다)

- **대화 / 오늘의 기분 / 칭찬판 / 반응 / 읽음 처리 / 오늘의 질문**: `services/`의 Supabase 직접 호출 함수를 통해 Realtime 구독으로 받는다. RLS가 보안을 담당하므로 화면에서 family_id 필터링을 다시 구현하지 않는다.
- **가족 생성/초대, 아이 QR 로그인**: `services/api.ts`(backend REST 래퍼)를 통해 `backend`를 호출한다. Supabase Auth Admin API나 service-role이 필요한 작업을 frontend가 직접 수행하지 않는다.
- 로그인한 구성원 정보(역할: parent/kid, family_id)는 인증 컨텍스트(Context API)로 앱 전역에 제공한다. 화면 내부 UI 상태만 로컬 `useState`로 관리한다.

## 디자인

- `docs/UI_GUIDE.md`의 색상/타이포/컴포넌트 토큰을 그대로 쓴다 (크림 배경, 둥근 모서리, AI 슬롭 안티패턴 금지 목록 포함).
- 아이가 혼자 쓸 화면은 글보다 이모지/스티커/큰 버튼을 우선한다.

## 테스트

- `npm run test --workspace=frontend` (Jest)는 네트워크/Supabase 없이 순수 로직(`lib/`)과 컴포넌트 렌더링만 검증한다. Supabase/backend 연동은 수동으로 Expo 앱을 띄워 확인한다(`run-dev-stack` 스킬).

## 명령어

```bash
npx expo start                        # 개발 서버 (frontend/ 안에서)
npm run build --workspace=frontend    # 타입체크만 (tsc --noEmit, EAS 빌드 아님)
npm run test --workspace=frontend
npm run lint --workspace=frontend
```
