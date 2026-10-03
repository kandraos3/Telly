import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime configuration injected at build time with
/// `flutter run --dart-define-from-file=env/dev.json` (FE-601).
///
/// Only client-safe values live here: the Supabase anon key is public by design
/// (RLS enforces access). The service-role key must never be shipped in the app.
class AppConfig {
  final String appEnv;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String sentryDsn;
  final String posthogApiKey;
  final String posthogHost;
  final String privacyPolicyUrl;
  final String termsUrl;

  /// Deep link the OAuth providers redirect back to (registered in iOS/Android in FE-602).
  final String authRedirectUrl;

  const AppConfig({
    this.appEnv = 'development',
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.sentryDsn = '',
    this.posthogApiKey = '',
    this.posthogHost = 'https://app.posthog.com',
    this.privacyPolicyUrl = 'https://telly.app/privacy',
    this.termsUrl = 'https://telly.app/terms',
    this.authRedirectUrl = 'app.telly.mobile://login-callback',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        appEnv: String.fromEnvironment('APP_ENV', defaultValue: 'development'),
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
        sentryDsn: String.fromEnvironment('SENTRY_DSN'),
        posthogApiKey: String.fromEnvironment('POSTHOG_API_KEY'),
        posthogHost: String.fromEnvironment('POSTHOG_HOST', defaultValue: 'https://app.posthog.com'),
        privacyPolicyUrl: String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: 'https://telly.app/privacy'),
        termsUrl: String.fromEnvironment('TERMS_URL', defaultValue: 'https://telly.app/terms'),
        authRedirectUrl: String.fromEnvironment('AUTH_REDIRECT_URL', defaultValue: 'app.telly.mobile://login-callback'),
      );

  /// Names of required values that are missing or malformed.
  List<String> get missingRequired => [
        if (Uri.tryParse(supabaseUrl)?.hasScheme != true) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      ];

  bool get isValid => missingRequired.isEmpty;
  bool get isProduction => appEnv == 'production';
}

/// Overridden in `main()` with the validated config, and in tests with a fixture.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
