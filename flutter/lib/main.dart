import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/app_config.dart';
import 'services/devices_service.dart';
import 'services/families_service.dart';
import 'services/members_service.dart';
import 'services/moods_service.dart';
import 'services/praises_service.dart';
import 'services/push_notifications_service.dart';
import 'services/qr_auth_service.dart';
import 'services/rooms_service.dart';
import 'services/supabase_auth_backend.dart';
import 'state/auth_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();

  // 세션은 supabase_flutter가 SharedPreferences에 저장하고 자동 갱신한다 (RN의 AsyncStorage 설정에 대응).
  await Supabase.initialize(
    url: config.supabaseUrl,
    // pubspec.yaml은 하한만 ^2.8.4로 고정하지만, 설치된 2.18.x에서도 publishableKey
    // 대신 anonKey를 그대로 쓴다(deprecated 경고만 뜨고 동작은 동일).
    // ignore: deprecated_member_use
    anonKey: config.supabaseAnonKey,
  );
  final supabase = Supabase.instance.client;

  final parentAuth = ParentAuthService(supabase);

  // FCM 푸시 토큰 등록 (선택 기능). Firebase 설정 파일이 없으면 조용히 건너뛴다.
  final pushNotifications = PushNotificationsService(
    FirebasePushMessagingGateway(),
    osName: kIsWeb ? null : Platform.operatingSystem,
  );
  unawaited(pushNotifications.configureNotificationHandler());
  late final AuthController authController;
  final pushRegistrar = PushDeviceRegistrar(
    push: pushNotifications,
    devices: SupabaseDevicesService(
      supabase,
      currentMember: () async => authController.member,
    ),
  );
  authController = AuthController(
    SupabaseAuthBackend(supabase),
    onMemberReady: (_) => pushRegistrar.register(),
  )..initialize();
  final membersService = SupabaseMembersService(supabase);
  final api = ApiClient(
    baseUrl: config.backendUrl,
    httpClient: http.Client(),
    accessTokenProvider: parentAuth.accessToken,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<ParentAuthService>.value(value: parentAuth),
        Provider<FamiliesService>.value(value: FamiliesService(api)),
        Provider<QrAuthService>.value(
          value: QrAuthService(
            api,
            // 아이 기기 redeem 응답 세션 적용. onAuthStateChange → AuthController가 members를 다시 읽는다.
            applySession: (accessToken, refreshToken) async {
              await supabase.auth
                  .setSession(refreshToken, accessToken: accessToken);
            },
          ),
        ),
        Provider<MembersService>.value(value: membersService),
        // 대화 데이터는 Supabase 직접 호출 + Realtime (ADR-004 "일상 데이터"). sender_id/member_id는
        // AuthController가 이미 읽어 둔 members 행을 쓴다 (RLS가 auth.uid()와의 일치를 다시 검증).
        Provider<RoomsService>.value(
          value: SupabaseRoomsService(
            supabase,
            members: membersService,
            currentMember: () async => authController.member,
          ),
        ),
        // 칭찬판도 Supabase 직접 호출 (ADR-004). 접근 범위는 RLS(praise_boards/praises)가 강제한다.
        Provider<PraisesService>.value(
          value: SupabasePraisesService(
            supabase,
            members: membersService,
            currentMember: () async => authController.member,
          ),
        ),
        // 기분도 Supabase 직접 호출 (ADR-004). 이유(note) 공개 범위는 RLS(mood_notes_select)가 강제한다.
        Provider<MoodsService>.value(
          value: SupabaseMoodsService(
            supabase,
            currentMember: () async => authController.member,
          ),
        ),
        ChangeNotifierProvider<AuthController>.value(value: authController),
      ],
      child: const FamilyTokTokApp(),
    ),
  );
}

class FamilyTokTokApp extends StatelessWidget {
  const FamilyTokTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우리가족톡톡',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
