library account_deletion_service;

import 'dart:async';

/// Status of account in the 30-day soft deletion pipeline.
enum AccountDeletionStatus {
  active,
  pendingDeletion,
  purged,
}

/// Record tracking user deletion schedule.
class AccountDeletionRecord {
  final String userId;
  final AccountDeletionStatus status;
  final DateTime scheduledAt;
  final DateTime purgeDeadline;
  final String? reason;

  const AccountDeletionRecord({
    required this.userId,
    required this.status,
    required this.scheduledAt,
    required this.purgeDeadline,
    this.reason,
  });

  bool get isExpired => DateTime.now().isAfter(purgeDeadline);
}

/// Service managing GDPR/Apple Guideline 1.2 compliant 30-day soft deletion pipeline.
/// Conforms to `LEGAL-502` and `docs/adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md` §4.
class AccountDeletionService {
  final Map<String, AccountDeletionRecord> _records = {};

  /// Schedule user account for 30-day soft deletion.
  Future<AccountDeletionRecord> scheduleDeletion({
    required String userId,
    String? reason,
  }) async {
    final now = DateTime.now();
    final deadline = now.add(const Duration(days: 30));

    final record = AccountDeletionRecord(
      userId: userId,
      status: AccountDeletionStatus.pendingDeletion,
      scheduledAt: now,
      purgeDeadline: deadline,
      reason: reason,
    );

    _records[userId] = record;
    return record;
  }

  /// Reactivate account if user logs back in during the 30-day grace period.
  Future<bool> cancelDeletion({required String userId}) async {
    final record = _records[userId];
    if (record == null) return false;

    if (record.isExpired) {
      return false; // Already beyond 30 days, cannot cancel
    }

    _records[userId] = AccountDeletionRecord(
      userId: userId,
      status: AccountDeletionStatus.active,
      scheduledAt: record.scheduledAt,
      purgeDeadline: record.purgeDeadline,
      reason: null,
    );
    return true;
  }

  /// Background cron task purging accounts whose 30-day grace period has elapsed.
  Future<List<String>> purgeExpiredAccounts() async {
    final purgedUserIds = <String>[];

    for (final entry in _records.entries) {
      if (entry.value.status == AccountDeletionStatus.pendingDeletion && entry.value.isExpired) {
        purgedUserIds.add(entry.key);
      }
    }

    for (final userId in purgedUserIds) {
      _records[userId] = AccountDeletionRecord(
        userId: userId,
        status: AccountDeletionStatus.purged,
        scheduledAt: _records[userId]!.scheduledAt,
        purgeDeadline: _records[userId]!.purgeDeadline,
        reason: 'Expired 30-day purge cycle',
      );
    }

    return purgedUserIds;
  }

  AccountDeletionRecord? getRecord(String userId) => _records[userId];
}

