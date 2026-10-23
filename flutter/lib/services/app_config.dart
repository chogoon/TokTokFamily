/// 빌드 시 `--dart-define-from-file=.env`로 주입되는 환경값. RN `frontend/.env.example`에 대응.
/// 키는 git에 커밋하지 않는다 (`flutter/.env`는 .gitignore 대상, `.env.example`만 커밋).
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.backendUrl,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String backendUrl;

  static AppConfig fromEnvironment() {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const backendUrl = String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'http://localhost:4000',
    );

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be set '
        '(flutter run --dart-define-from-file=.env)',
      );
    }

    return const AppConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      backendUrl: backendUrl,
    );
  }
}
