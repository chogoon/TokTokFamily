import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/app_config.dart';
import 'services/families_service.dart';
import 'services/supabase_auth_backend.dart';
import 'state/auth_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();

  // 세션은 supabase_flutter가 SharedPreferences에 저장하고 자동 갱신한다 (RN의 AsyncStorage 설정에 대응).
  await Supabase.initialize(
    url: config.supabaseUrl,
    // supabase_flutter 2.8.x(Flutter 3.16 호환)에는 publishableKey가 없어 anonKey를 유지한다.
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
