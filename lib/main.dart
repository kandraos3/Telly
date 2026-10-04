import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/analytics/telemetry_service.dart';
import 'core/config/app_config.dart';
import 'core/config/config_error_app.dart';
import 'core/config/secure_session_storage.dart';
import 'core/monitoring/sentry_service.dart';

/// Entry point. Run with `flutter run --dart-define-from-file=env/dev.json` (see env/example.json).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (!config.isValid) {
    // Fail fast and visibly: never fall back to mock auth (audit C2).
    runApp(ConfigErrorApp(missing: config.missingRequired));
    return;
  }

  // Set up FlutterError.onError hook for real crash reporting (DEV-601).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    SentryService().captureException(
      details.exception,
      details.stack,
      {'library': details.library, 'context': details.context?.toString()},
      'flutter_error',
    );
  };

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey, // anon (legacy) or publishable key — both are client-safe
    authOptions: const FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
  );

  // Initialize PostHog product telemetry if API key configured (DEV-601).
  if (config.posthogApiKey.isNotEmpty) {
    await TelemetryService().initialize(apiKey: config.posthogApiKey);
  }

  Widget buildRootApp() => ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const TellyApp(),
      );

  // Wrap runApp with SentryFlutter when DSN is provided, no-op when absent (DEV-601).
  if (config.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = config.sentryDsn;
        options.tracesSampleRate = 1.0;
        options.environment = config.isProduction ? 'production' : 'development';
      },
      appRunner: () => runApp(buildRootApp()),
    );
  } else {
    runApp(buildRootApp());
  }
}

