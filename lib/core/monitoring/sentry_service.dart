library sentry_service;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Breadcrumb representation for tracking user actions prior to an error.
class TellyBreadcrumb {
  final String category; // 'navigation', 'duel', 'network', 'auth'
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const TellyBreadcrumb({
    required this.category,
    required this.message,
    this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'message': message,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Sentry monitoring and crash diagnostics service.
/// Conforms to `DEV-503`, `DEV-601`, and `docs/technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md` §3.1.
class SentryService {
  static final SentryService _instance = SentryService._internal();
  factory SentryService() => _instance;
  SentryService._internal();

  bool _initialized = false;
  String _environment = 'production';
  final List<TellyBreadcrumb> _breadcrumbs = [];
  final List<Map<String, dynamic>> _capturedExceptions = [];

  bool get isInitialized => _initialized;
  String get environment => _environment;
  List<TellyBreadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);
  List<Map<String, dynamic>> get capturedExceptions => List.unmodifiable(_capturedExceptions);

  /// Initialize monitoring with DSN and environment.
  Future<void> initialize({
    required String dsn,
    String environment = 'production',
    double tracesSampleRate = 1.0,
  }) async {
    _environment = environment;
    _initialized = true;
    _breadcrumbs.clear();
    _capturedExceptions.clear();
  }

  /// Record navigation route transition.
  void addNavigationBreadcrumb(String routeName) {
    _addBreadcrumb(
      TellyBreadcrumb(
        category: 'navigation',
        message: 'Navigated to $routeName',
        timestamp: DateTime.now(),
      ),
    );
    if (Sentry.isEnabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'navigation',
          message: 'Navigated to $routeName',
          level: SentryLevel.info,
        ),
      );
    }
  }

  /// Record duel decision for debugging tournament state.
  void addDuelBreadcrumb({
    required int showAId,
    required int showBId,
    required int winnerId,
    bool isUpset = false,
  }) {
    _addBreadcrumb(
      TellyBreadcrumb(
        category: 'duel',
        message: 'Duel decided: Winner #$winnerId over #${winnerId == showAId ? showBId : showAId}',
        data: {
          'candidate_a': showAId,
          'candidate_b': showBId,
          'winner': winnerId,
          'is_upset': isUpset,
        },
        timestamp: DateTime.now(),
      ),
    );
    if (Sentry.isEnabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'duel',
          message: 'Duel decided: Winner #$winnerId over #${winnerId == showAId ? showBId : showAId}',
          data: {
            'candidate_a': showAId,
            'candidate_b': showBId,
            'winner': winnerId,
            'is_upset': isUpset,
          },
          level: SentryLevel.info,
        ),
      );
    }
  }

  /// Record network request metadata.
  void addNetworkBreadcrumb({
    required String url,
    required String method,
    int? statusCode,
  }) {
    _addBreadcrumb(
      TellyBreadcrumb(
        category: 'network',
        message: '$method $url [${statusCode ?? 'PENDING'}]',
        data: {'url': url, 'method': method, 'status_code': statusCode},
        timestamp: DateTime.now(),
      ),
    );
    if (Sentry.isEnabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'network',
          message: '$method $url [${statusCode ?? 'PENDING'}]',
          data: {'url': url, 'method': method, 'status_code': statusCode},
          level: SentryLevel.info,
        ),
      );
    }
  }

  void _addBreadcrumb(TellyBreadcrumb breadcrumb) {
    if (_breadcrumbs.length >= 100) {
      _breadcrumbs.removeAt(0); // keep fixed buffer of 100
    }
    _breadcrumbs.add(breadcrumb);
  }

  /// Capture exception with stack trace and context.
  Future<void> captureException(
    dynamic exception, [
    dynamic stackTrace,
    Map<String, dynamic>? extra,
    String? action,
  ]) async {
    final mergedExtra = <String, dynamic>{
      if (extra != null) ...extra,
      if (action != null) 'action': action,
    };

    _capturedExceptions.add({
      'exception': exception.toString(),
      'stackTrace': stackTrace?.toString(),
      'extra': mergedExtra.isEmpty ? null : mergedExtra,
      'timestamp': DateTime.now().toIso8601String(),
      'breadcrumbs_count': _breadcrumbs.length,
    });

    if (Sentry.isEnabled) {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        withScope: (scope) {
          for (final entry in mergedExtra.entries) {
            scope.setContexts(entry.key, entry.value);
          }
        },
      );
    }
  }

  /// Capture text warning or notice.
  void captureMessage(String message, {String level = 'info'}) {
    _breadcrumbs.add(
      TellyBreadcrumb(
        category: 'message',
        message: '[$level] $message',
        timestamp: DateTime.now(),
      ),
    );
    if (Sentry.isEnabled) {
      final sentryLevel = switch (level.toLowerCase()) {
        'warning' => SentryLevel.warning,
        'error' => SentryLevel.error,
        'fatal' => SentryLevel.fatal,
        _ => SentryLevel.info,
      };
      Sentry.captureMessage(message, level: sentryLevel);
    }
  }

  /// Clear monitoring state (for testing).
  void reset() {
    _initialized = false;
    _breadcrumbs.clear();
    _capturedExceptions.clear();
  }
}

final sentryServiceProvider = Provider<SentryService>((ref) => SentryService());
