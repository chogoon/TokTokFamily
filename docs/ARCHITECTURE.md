# 아키텍처

## 디렉토리 구조

```text
app/                   # Expo Router 화면 (탭: 대화/기분/칭찬/가족)
├── (auth)/            # 가족 생성, 초대, 아이 QR 로그인
├── (tabs)/            # 대화 / 기분 / 칭찬 / 가족 탭
components/            # 재사용 UI 컴포넌트 (버튼, 말풍선, 스티커 등)
types/                 # TypeScript 타입 정의 (families, members, rooms, messages ...)
lib/                   # 유틸리티 + 헬퍼 (날짜 포맷, QR 토큰 등)
services/              # Supabase 클라이언트 + 쿼리 래퍼 (families, rooms, moods, praises)
```

## 패턴

화면은 Supabase Realtime 구독으로 데이터를 받는 "구독 기반 화면" 패턴을 기본으로 한다. `services/`의 함수가 Supabase 쿼리/구독을 감싸고, 화면 컴포넌트는 반환된 데이터만 렌더링한다. 화면이 직접 Supabase 클라이언트를 호출하지 않는다.

## 데이터 흐름

```text
사용자 입력 (메시지 전송, 기분 선택, 칭찬 스티커 붙이기)
  → 화면 컴포넌트
  → services/ 함수 (Supabase insert/update)
  → Supabase (RLS 검증 → Postgres 반영)
  → Realtime 구독으로 변경 전파
  → 가족 구성원 화면 업데이트
```

## 상태 관리

- 서버 상태(가족/방/메시지/기분/칭찬)는 Supabase Realtime 구독으로 관리한다. 별도의 전역 상태 라이브러리로 캐시를 복제하지 않는다.
- 로그인한 구성원 정보(역할: parent/kid, family_id)는 인증 컨텍스트(Context API)로 앱 전역에 제공한다.
- 화면 내부 UI 상태(입력창 텍스트, 탭 선택 등)만 로컬 `useState`로 관리한다.
