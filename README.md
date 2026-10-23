# Family TokTok (우리가족 톡톡)

초등학생 자녀와 부모만 사용하는 가족 전용 메신저 앱. 친구 추가, 공개 프로필, 외부 공유, 좋아요 순위, 형제 비교 같은 기능은 설계 단계부터 영구적으로 배제한다 (`Family-TokTok-프로젝트-기획서.md` 참조).

## 핵심 기능

- **가족 만들기 / 초대**: 부모가 가족을 생성하고 초대 코드로 다른 보호자(조부모 등)를 추가
- **아이 로그인**: 이메일·비밀번호 없이 QR 스캔 또는 6자리 숫자 코드로 기기 연결
- **대화**: 가족방 + 아이별 1:1 방, 스티커/반응, 빠른 답장, 안읽음 표시, 긴급 버튼
- **오늘의 기분**: 이모지 선택(가족 전체 공개) + 이유(본인·보호자만 공개), 슬픔/화남 시 보호자에게 자동 알림
- **칭찬판**: 아이별 스티커 보드 + 보상 목표, 목표 달성 후 새 판
- **오늘의 가족 질문**: 가족방에 매일 새 질문 노출
- **푸시 알림**: 새 메시지·긴급 메시지·칭찬 발생 시 발송

## 기술 스택

npm workspaces 모노레포 + Flutter 별도 클라이언트.

| 영역 | 구성 |
| --- | --- |
| frontend | React Native + Expo (Expo Router), TypeScript |
| flutter | Flutter (Dart) — React Native와 별도의 두 번째 클라이언트 |
| backend | Node.js + Express + TypeScript |
| DB / Auth / Realtime | Supabase (PostgreSQL, Row Level Security, Realtime, Auth) |
| 배포 | Docker, Fly.io (backend), Supabase 호스팅 프로젝트 |

## 디렉토리 구조

```text
frontend/        React Native + Expo 클라이언트 (app/, services/, lib/, contexts/, types/)
flutter/         Flutter 클라이언트 (lib/screens, lib/services, lib/state ...)
backend/         Express API (가족 생성/초대, QR·숫자코드 로그인, 푸시 디스패치)
supabase/        DB 스키마 마이그레이션 + RLS 정책 (Supabase CLI 프로젝트)
docs/            PRD, 아키텍처, ADR, UI 가이드, 배포 런북
```

각 workspace의 세부 규칙은 `CLAUDE.md`, `frontend/CLAUDE.md`, `backend/CLAUDE.md`를 참고한다.

## 아키텍처 요약

데이터 접근 경로를 두 가지로 분리한다 (`docs/ARCHITECTURE.md`, `docs/ADR.md` 참조).

- **프론트 → Supabase 직접**: 대화, 기분, 칭찬판, 반응, 읽음 처리 등 고빈도 실시간 데이터는 클라이언트가 Supabase RLS를 거쳐 직접 접근한다.
- **프론트 → backend 경유**: 가족 생성/초대 부트스트랩, 아이 QR·숫자코드 로그인, 푸시 디스패치처럼 service-role 권한이 필요한 작업만 Express backend를 통해 처리한다.

형제 간 데이터 격리(1:1 방, 기분 이유, 칭찬판)와 아동 개인정보 최소화는 DB RLS 정책, 백엔드 인가 로직, UI 세 단계에서 중복으로 방어한다.

## 로컬 개발

```bash
npm install                 # 루트에서 전체 workspace 설치
npm run lint                # 두 workspace lint fan-out
npm run build                # 두 workspace build fan-out
npm run test                 # 두 workspace test fan-out
```

로컬 전체 스택(Supabase + backend + frontend) 실행은 `run-dev-stack` 스킬을 사용한다 (`npx supabase start` → backend → frontend 순서로 기동, 자세한 내용은 `.claude/skills/run-dev-stack/SKILL.md` 참조).

Flutter 클라이언트는 `flutter/` 디렉토리에서 별도로 실행한다.

```bash
cd flutter
flutter pub get
flutter run --dart-define-from-file=.env
```

## 배포

- **Supabase**: 운영 프로젝트에 `supabase/migrations/`를 `supabase db push`로 적용
- **backend**: `backend/Dockerfile` 기반으로 Fly.io에 배포 (`fly.toml`)
- **frontend**: 현재 Expo 개발 빌드 단계, 앱스토어 제출은 별도 범위

자세한 단계별 절차는 `docs/DEPLOYMENT.md`를 참고한다.

## 문서

- `docs/PRD.md` — 제품 요구사항
- `docs/ARCHITECTURE.md` — 데이터 흐름, 스키마 설계
- `docs/ADR.md` — 아키텍처 의사결정 기록
- `docs/UI_GUIDE.md` — 디자인 토큰, 컴포넌트 가이드
- `docs/DEPLOYMENT.md` — 운영 배포 런북
