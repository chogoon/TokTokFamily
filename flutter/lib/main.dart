import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/app_config.dart';
import 'services/families_service.dart';
import 'services/members_service.dart';
import 'services/qr_auth_service.dart';
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
        Provider<MembersService>.value(value: SupabaseMembersService(supabase)),
        ChangeNotifierProvider<AuthController>(
          create: (_) =>
              AuthController(SupabaseAuthBackend(supabase))..initialize(),
        ),
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
