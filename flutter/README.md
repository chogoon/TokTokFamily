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

- `lib/services/` — Supabase 직접 호출(`supabase_auth_backend.dart`, `members_service.dart`) + backend REST 래퍼(`api_client.dart`, `families_service.dart`, `qr_auth_service.dart`)
- `lib/models/` — 데이터 모델 (`members` 행 등)
- `lib/state/` — `AuthController`(ChangeNotifier + provider): 로그인한 구성원/role/family_id 전역 제공
- `lib/screens/`, `lib/widgets/` — 화면/재사용 위젯 (`family_screen.dart` 가족 화면, `qr_issue_screen.dart` 아이 기기 연결 QR — QR은 `qr_flutter`로 렌더)
- `lib/theme/` — `docs/UI_GUIDE.md` 토큰
- `lib/utils/` — 입력 검증, 에러 문구 매핑, QR 카운트다운, 아이 팔레트(`kid_palette.dart` — backend `kidPalette.ts`와 동기화) 등 순수 함수 (테스트 대상)

## 푸시 알림 (FCM)

Flutter는 Expo 생태계가 아니므로 Expo Push 토큰 대신 **FCM registration token**을 발급받아
`devices`에 `provider: 'fcm'`으로 등록한다 (`lib/services/devices_service.dart`). backend
`pushDispatch.ts`가 provider별로 Expo Push API / Firebase Admin SDK로 라우팅한다.

- 로그인 완료(`AuthController.refreshMember`에서 member 조회 성공) 시 `PushDeviceRegistrar`가
  권한 요청 → `getToken()` → `devices` select-then-insert를 수행한다. 모든 실패는 삼킨다(soft-fail).
- **Firebase 설정 파일이 없어도 앱은 정상 빌드·실행된다.** `Firebase.initializeApp()` 실패를 감지해
  푸시 등록만 조용히 건너뛴다. Android의 `com.google.gms.google-services` 플러그인은
  `android/app/google-services.json`이 있을 때만 적용된다(`android/app/build.gradle`).

### 실제 Firebase 프로젝트 연동

Firebase 프로젝트(`toktokfamily-c38b9`)에 Android 앱(`com.toktokfamily.toktok_family`)과 iOS 앱
(`com.toktokfamily.toktokFamily`)이 이미 `flutterfire configure`로 등록되어 있다
(`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`,
`firebase.json`, `.firebaserc` 전부 커밋됨). 남은 건 아래 수동 단계뿐이다:

1. iOS: Apple Developer에서 APNs 인증 키(.p8)를 발급해 Firebase 콘솔 > Cloud Messaging에 업로드하고,
   Xcode에서 Push Notifications / Background Modes(Remote notifications) capability 추가.
2. backend: Firebase 콘솔 > 프로젝트 설정 > 서비스 계정에서 비공개 키(JSON)를 받아
   `FIREBASE_SERVICE_ACCOUNT_KEY` 환경변수로 설정.
3. 설정 파일을 다시 받아야 할 때(앱 재등록 등)는 `flutterfire configure --project=toktokfamily-c38b9
   --platforms=android,ios --android-package-name=com.toktokfamily.toktok_family
   --ios-bundle-id=com.toktokfamily.toktokFamily`로 재실행한다.
