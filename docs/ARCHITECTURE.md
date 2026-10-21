# 아키텍처

npm workspaces 모노레포: `frontend/`(React Native + Expo), `backend/`(Express + TypeScript), `supabase/`(저장소 루트 — migrations + RLS).

## 디렉토리 구조

```text
frontend/
├── app/                   # Expo Router 화면 (탭: 대화/기분/칭찬/가족)
│   ├── (auth)/            # 가족 생성, 초대, 아이 QR 로그인 (backend REST 경유)
│   └── (tabs)/            # 대화 / 기분 / 칭찬 / 가족 탭 (Supabase 직접 구독)
├── components/            # 재사용 UI 컴포넌트 (버튼, 말풍선, 스티커 등)
├── types/                 # TypeScript 타입 정의 (families, members, rooms, messages ...)
├── lib/                   # 유틸리티 + 헬퍼 (날짜 포맷, QR 토큰 파싱 등)
└── services/              # Supabase 클라이언트+쿼리 래퍼, backend REST 호출 래퍼
backend/
└── src/
    ├── routes/            # families, qrAuth, pushWebhook, health
    ├── lib/               # supabaseAdmin(service-role), expoPush
    └── middleware/        # verifyJwt, verifyWebhookSecret
supabase/                  # Supabase CLI 프로젝트 (migrations + RLS 정책)
```

## 패턴

화면은 어느 경로든 `services/`를 통해서만 접근한다.

- **대화 / 오늘의 기분 / 칭찬판 / 반응 / 읽음 처리 / 오늘의 질문**: Supabase Realtime 구독으로 데이터를 받는 "구독 기반 화면" 패턴. `services/`의 Supabase 직접 호출 함수가 쿼리/구독을 감싸고, 화면 컴포넌트는 반환된 데이터만 렌더링한다. 화면이 직접 Supabase 클라이언트를 호출하지 않는다.
- **가족 생성/초대, 아이 QR 로그인**: `services/api.ts`를 경유해 `backend`의 REST 엔드포인트를 호출한다. 화면이 Supabase Auth Admin API나 service-role 권한이 필요한 작업을 직접 수행하지 않는다.

## 데이터 흐름

### 프론트 → Supabase 직접 (일상 데이터)

```text
사용자 입력 (메시지 전송, 기분 선택, 칭찬 스티커 붙이기)
  → 화면 컴포넌트
  → services/ 함수 (Supabase insert/update)
  → Supabase (RLS 검증 → Postgres 반영)
  → Realtime 구독으로 변경 전파
  → 가족 구성원 화면 업데이트
```

### 프론트 → backend 경유 (민감/부트스트랩 작업)

```text
[가족 생성 / 초대]
  사용자 입력 → frontend services/families.ts → backend POST /families (또는 /invites/redeem)
  → backend가 Service Role로 families + members 행을 한 트랜잭션으로 생성
  → 생성된 family_id/member_id를 frontend에 반환 → frontend가 Supabase 세션으로 이후 접근

[아이 QR 로그인]
  부모 화면이 QR 표시용 토큰 요청 → backend POST /auth/qr/issue (부모 JWT로 인증, 짧은 만료 토큰 생성)
  → 아이 기기가 QR 스캔 → backend POST /auth/qr/redeem
  → backend가 토큰 검증(미사용·미만료) 후 Supabase Auth Admin API로 아이 세션 발급
  → access/refresh token을 아이 기기에 반환 → 이후 아이 기기는 그 세션으로 Supabase 직접 접근(RLS 적용)

[푸시 알림]
  메시지/기분/칭찬 insert (Postgres) → Supabase Database Webhook → backend POST /webhooks/push
  (PUSH_WEBHOOK_SECRET으로 발신 검증) → backend가 Service Role로 수신자 device 토큰 조회
  → expo-server-sdk로 Expo Push API 호출 → 수신자 기기 푸시 도착
```

## 상태 관리

- 서버 상태(가족/방/메시지/기분/칭찬)는 Supabase Realtime 구독으로 관리한다. 별도의 전역 상태 라이브러리로 캐시를 복제하지 않는다.
- 로그인한 구성원 정보(역할: parent/kid, family_id)는 인증 컨텍스트(Context API)로 앱 전역에 제공한다.
- 화면 내부 UI 상태(입력창 텍스트, 탭 선택 등)만 로컬 `useState`로 관리한다.
