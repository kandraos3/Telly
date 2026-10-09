import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';

/// A Supabase client whose server answers "nothing tracked" and whose calls never leave the test.
SupabaseClient emptyTrackingServer() => SupabaseClient(
      'http://supabase.test',
      'anon-key',
      httpClient: MockClient((req) async => http.Response(
            jsonEncode({'today': '2026-10-09', 'items': <Object>[]}),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          )),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

/// The real local-first tracking repository over [db], at a fixed [now] (2026-10-09 noon by default).
LocalFirstTrackingRepository trackingRepositoryFor(AppDatabase db, {DateTime? now}) =>
    LocalFirstTrackingRepository(db, emptyTrackingServer(), clock: () => now ?? DateTime(2026, 10, 9, 12));

/// Overrides that keep tracking inside the test: the real repository over an in-memory database.
List<Override> trackingOverrides(AppDatabase db, {DateTime? now}) => [
      databaseProvider.overrideWithValue(db),
      trackingRepositoryProvider.overrideWithValue(trackingRepositoryFor(db, now: now)),
    ];

/// Unmounts the tree and lets Drift's stream clean-up timers run, so the test ends with none
/// pending and the database can close.
Future<void> unmountTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
}

/// Pumps until the tree is quiet, giving Drift's real async work time to land between pumps.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }
}
