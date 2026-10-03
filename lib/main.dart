import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/config_error_app.dart';
import 'core/config/secure_session_storage.dart';

/// Entry point. Run with `flutter run --dart-define-from-file=env/dev.json` (see env/example.json).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (!config.isValid) {
    // Fail fast and visibly: never fall back to mock auth (audit C2).
    runApp(ConfigErrorApp(missing: config.missingRequired));
    return;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey, // anon (legacy) or publishable key — both are client-safe
    authOptions: const FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
  );

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const TellyApp(),
    ),
  );
}
