import 'dart:async';
import 'package:telly_app/core/sync/connectivity_signal.dart';

/// Controllable connectivity service for integration tests and CUJ-04 resilience tests.
class TestConnectivityService implements ConnectivityService {
  TestConnectivityService({bool initialOnline = true}) : _isOnline = initialOnline;

  bool _isOnline;
  final _controller = StreamController<bool>.broadcast();

  void setOnline(bool online) {
    _isOnline = online;
    _controller.add(_isOnline);
  }

  @override
  Future<bool> isOnline() async => _isOnline;

  @override
  Stream<bool> watchOnline() async* {
    yield _isOnline;
    yield* _controller.stream;
  }

  void dispose() {
    _controller.close();
  }
}
