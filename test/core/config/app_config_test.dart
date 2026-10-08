import 'dart:io';

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

  test('#155: a Supabase secret key is never accepted as the anon key', () {
    const secret = AppConfig(supabaseUrl: 'https://abc.supabase.co', supabaseAnonKey: 'sb_secret_xyz');
    expect(secret.missingRequired, ['SUPABASE_ANON_KEY']);
    const publishable = AppConfig(supabaseUrl: 'https://abc.supabase.co', supabaseAnonKey: 'sb_publishable_xyz');
    expect(publishable.isValid, isTrue);
  });

  testWidgets('ConfigErrorApp explains what is missing', (tester) async {
    await tester.pumpWidget(const ConfigErrorApp(missing: ['SUPABASE_URL']));
    expect(find.text('Telly is not configured'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });

  test('FE-602: the OAuth redirect scheme is registered on Android and iOS', () {
    final redirect = Uri.parse(AppConfig.fromEnvironment().authRedirectUrl);
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:scheme="${redirect.scheme}" android:host="${redirect.host}"'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>${redirect.scheme}</string>'));
  });
}
