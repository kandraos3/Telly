import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/config/app_config.dart';
import 'package:telly_app/core/config/config_error_app.dart';

/// FE-601: missing configuration fails fast instead of silently using mock auth.
void main() {
  test('a build without dart-defines is invalid and names the missing keys', () {
    final config = AppConfig.fromEnvironment(); // flutter test passes no --dart-define
    expect(config.isValid, isFalse);
    expect(config.missingRequired, containsAll(['SUPABASE_URL', 'SUPABASE_ANON_KEY']));
  });

  test('a complete config is valid', () {
    const config = AppConfig(supabaseUrl: 'https://abc.supabase.co', supabaseAnonKey: 'anon');
    expect(config.isValid, isTrue);
    expect(config.isProduction, isFalse);
  });

  test('a malformed URL is rejected', () {
    const config = AppConfig(supabaseUrl: 'not a url', supabaseAnonKey: 'anon');
    expect(config.missingRequired, ['SUPABASE_URL']);
  });

  testWidgets('ConfigErrorApp explains what is missing', (tester) async {
    await tester.pumpWidget(const ConfigErrorApp(missing: ['SUPABASE_URL']));
    expect(find.text('Telly is not configured'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
