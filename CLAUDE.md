# 프로젝트: Family TokTok (우리가족 톡톡)

초등학생 자녀와 부모만 쓰는, 가족 전용 대화 앱. 현재 상태: 웹 프로토타입(`family-sns.html`)만 존재, 앱 개발 미시작.

## 기술 스택

- React Native + Expo (iOS/Android 동시 대응)
- TypeScript strict mode
- Supabase (Auth, Postgres, Realtime, Storage)
- Expo Notifications (FCM / APNs)

## 아키텍처 규칙

- CRITICAL: 모든 데이터 접근은 Supabase RLS(행 단위 보안)를 거쳐야 한다. 클라이언트에서 family_id 필터링을 자체 구현해 RLS를 대체하지 말 것.
- CRITICAL: 1:1 방(`rooms.type=kid`)은 해당 아이와 보호자만 읽고 쓸 수 있다. 형제가 다른 아이의 1:1 방이나 `moods.note`, `praise_boards`에 접근하는 경로를 만들지 말 것.
- CRITICAL: 친구 추가, 공개 프로필, 외부 공유, 좋아요 순위, 형제 비교 화면은 어떤 형태로도 구현하지 말 것 (`Family-TokTok-프로젝트-기획서.md` 2장 핵심 원칙 참조).
- 아이 계정은 이메일/비밀번호 없이 부모 폰의 QR을 찍어 기기 연결(QR 토큰은 일정 시간 후 만료)로 로그인한다.
- 화면/컴포넌트는 `screens/`, `components/`에, 타입은 `types/`에, Supabase 클라이언트·쿼리는 `services/`에 분리한다.

## 개발 프로세스

- CRITICAL: 새 기능 구현 시 반드시 테스트를 먼저 작성하고, 테스트가 통과하는 구현을 작성할 것 (TDD)
- 커밋 메시지는 conventional commits 형식을 따를 것 (feat:, fix:, docs:, refactor:)
- 아이에게는 이름(별명)과 캐릭터 외의 개인정보(전화번호, 이메일, 생년월일, 학교)를 요구하는 필드를 추가하지 말 것

## 명령어

```bash
npx expo start       # 개발 서버
eas build            # 프로덕션 빌드
npm run lint         # ESLint
npm run test         # 테스트
```
