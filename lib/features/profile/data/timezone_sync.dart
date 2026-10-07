import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../core/network/supabase_providers.dart';

/// Keeps `users.timezone` matching the device (features/10 §3, #139): weekly streaks run
/// Monday to Sunday in the user's own time zone.
///
/// The app shell calls [sync] when it starts (sign-in) and on every resume, which covers a
/// time-zone change while travelling. The last zone sent is remembered for the session, so
/// an unchanged zone costs nothing; failures are retried on the next call.
class TimezoneSync {
  TimezoneSync({required Future<String> Function() deviceZone, required Future<void> Function(String zone) send})
      : _deviceZone = deviceZone,
        _send = send;

  final Future<String> Function() _deviceZone;
  final Future<void> Function(String zone) _send;
  String? _lastSent;
  Future<void>? _inFlight;

  Future<void> sync() => _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<void> _run() async {
    try {
      final zone = await _deviceZone();
      if (zone.isEmpty || zone == _lastSent) return;
      await _send(zone);
      _lastSent = zone;
    } catch (_) {
      // Unknown or unreadable zone, or offline: keep the server's value and try again later.
    }
  }
}

/// The client is read only when sending, so creating this never touches Supabase.
final timezoneSyncProvider = Provider<TimezoneSync>((ref) => TimezoneSync(
      deviceZone: () async => (await FlutterTimezone.getLocalTimezone()).identifier,
      send: (zone) => ref.read(supabaseClientProvider).rpc('set_timezone', params: {'p_timezone': zone}),
    ));
