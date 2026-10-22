# family_toktok (Flutter 클라이언트)

Family TokTok의 Flutter 클라이언트. backend(`../backend`)와 Supabase(`../supabase`)를 RN `frontend/`와 공유한다.

## 실행

```bash
cp .env.example .env   # SUPABASE_ANON_KEY는 저장소 루트에서 `npx supabase status`로 확인
flutter pub get
flutter run --dart-define-from-file=.env          # 기기/시뮬레이터
flutter run -d chrome --dart-define-from-file=.env
flutter test
flutter analyze
```

Android 에뮬레이터는 `.env`의 `localhost`/`127.0.0.1`을 `10.0.2.2`로 바꿔야 한다.

## 구조

- `lib/services/` — Supabase 직접 호출(`supabase_auth_backend.dart`) + backend REST 래퍼(`api_client.dart`, `families_service.dart`)
- `lib/models/` — 데이터 모델 (`members` 행 등)
- `lib/state/` — `AuthController`(ChangeNotifier + provider): 로그인한 구성원/role/family_id 전역 제공
- `lib/screens/`, `lib/widgets/` — 화면/재사용 위젯
- `lib/theme/` — `docs/UI_GUIDE.md` 토큰
- `lib/utils/` — 입력 검증, 에러 문구 매핑 등 순수 함수 (테스트 대상)
