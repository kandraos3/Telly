import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Store listing used as the public share link while telly.app is not deployed.
const kDefaultShareUrl = 'https://play.google.com/store/apps/details?id=app.telly.mobile';

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

  /// Link appended to shared captions. Defaults to the store listing until the
  /// telly.app landing page is live (FE-LEGAL-01); override with `APP_SHARE_URL`.
  final String shareUrl;

  /// Deep link the OAuth providers redirect back to (registered in iOS/Android in FE-602).
  final String authRedirectUrl;

  const AppConfig({
    this.appEnv = 'development',
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.sentryDsn = '',
    this.posthogApiKey = '',
    this.posthogHost = 'https://app.posthog.com',
    this.shareUrl = kDefaultShareUrl,
    this.authRedirectUrl = 'app.telly.mobile://login-callback',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        appEnv: String.fromEnvironment('APP_ENV', defaultValue: 'development'),
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
        sentryDsn: String.fromEnvironment('SENTRY_DSN'),
        posthogApiKey: String.fromEnvironment('POSTHOG_API_KEY'),
        posthogHost: String.fromEnvironment('POSTHOG_HOST', defaultValue: 'https://app.posthog.com'),
        shareUrl: String.fromEnvironment('APP_SHARE_URL', defaultValue: kDefaultShareUrl),
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
