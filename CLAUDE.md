# 프로젝트: Family TokTok (우리가족 톡톡)

초등학생 자녀와 부모만 쓰는, 가족 전용 대화 앱. 현재 상태: 웹 프로토타입(`family-sns.html`)만 존재, 앱 개발 미시작.

이 파일은 `frontend/`와 `backend/` 양쪽에 공통인 규칙만 담는다. workspace별 세부 규칙은 각 폴더의 `CLAUDE.md`를 참조한다 (Claude Code는 작업 디렉토리 하위의 `CLAUDE.md`를 자동으로 함께 로드한다).

## 기술 스택

- npm workspaces 모노레포: `frontend/`(상세는 `frontend/CLAUDE.md`), `backend/`(상세는 `backend/CLAUDE.md`)
- TypeScript strict mode (양쪽 공통)
- Supabase (Auth, Postgres, Realtime, Storage) — migrations/RLS는 저장소 루트의 `supabase/`에 둔다 (frontend/backend가 공유하는 계약이므로 어느 한쪽 소유로 두지 않음)

## 제품 원칙 (CRITICAL — 모든 workspace 공통)

- CRITICAL: 1:1 방(`rooms.type=kid`)은 해당 아이와 보호자만 읽고 쓸 수 있다. 형제가 다른 아이의 1:1 방이나 `mood_notes`, `praise_boards`에 접근하는 경로를 만들지 말 것.
- CRITICAL: 친구 추가, 공개 프로필, 외부 공유, 좋아요 순위, 형제 비교 화면은 어떤 형태로도 구현하지 말 것 (`Family-TokTok-프로젝트-기획서.md` 2장 핵심 원칙 참조).
- 아이 계정은 이메일/비밀번호 없이 부모 폰의 QR을 찍어 기기 연결(QR 토큰은 짧은 시간 후 만료)로 로그인한다.
- 아이에게는 이름(별명)과 캐릭터 외의 개인정보(전화번호, 이메일, 생년월일, 학교)를 요구하는 필드를 추가하지 말 것

## 개발 프로세스

- CRITICAL: 새 기능 구현 시 반드시 테스트를 먼저 작성하고, 테스트가 통과하는 구현을 작성할 것 (TDD)
- 커밋 메시지는 conventional commits 형식을 따를 것 (feat:, fix:, docs:, refactor:)

## 명령어

```bash
npm install          # 루트에서 전체 workspace 설치
npm run lint          # 루트 — 두 workspace lint fan-out
npm run build          # 루트 — 두 workspace build fan-out
npm run test          # 루트 — 두 workspace test fan-out
```

로컬 전체 스택(Supabase + backend + frontend) 실행은 `run-dev-stack` 스킬을 쓴다 (`/run-dev-stack` 또는 "개발 서버 띄워줘"로 호출).
