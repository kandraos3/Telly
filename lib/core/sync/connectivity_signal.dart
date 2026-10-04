import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Interface for injectable network connectivity service (FE-605 / QA-602).
abstract class ConnectivityService {
  Future<bool> isOnline();
  Stream<bool> watchOnline();
}

class SystemConnectivityService implements ConnectivityService {
  final Connectivity _connectivity;
  SystemConnectivityService([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((c) => c != ConnectivityResult.none);
  }

  @override
  Stream<bool> watchOnline() async* {
    yield await isOnline();
    yield* _connectivity.onConnectivityChanged
        .map((results) => results.any((c) => c != ConnectivityResult.none))
        .distinct();
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return SystemConnectivityService();
});

/// Emits whether any network interface is up (FE-605). It is only a hint: a flush can
/// still fail, in which case the sync engine backs off and retries.
final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.watchOnline();
});
