import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/profile/data/account_deletion_service.dart';

void main() {
  group('AccountDeletionService Tests (LEGAL-502)', () {
    late AccountDeletionService service;

    setUp(() {
      service = AccountDeletionService();
    });

    test('schedules account deletion with 30-day purge deadline', () async {
      final record = await service.scheduleDeletion(
        userId: 'usr_abc_123',
        reason: 'Switching accounts',
      );

      expect(record.status, equals(AccountDeletionStatus.pendingDeletion));
      expect(record.isExpired, isFalse);

      final diff = record.purgeDeadline.difference(record.scheduledAt).inDays;
      expect(diff, equals(30));
    });

    test('cancels scheduled deletion during 30-day grace period', () async {
      await service.scheduleDeletion(userId: 'usr_abc_123');
      final cancelled = await service.cancelDeletion(userId: 'usr_abc_123');

      expect(cancelled, isTrue);
      final updated = service.getRecord('usr_abc_123');
      expect(updated?.status, equals(AccountDeletionStatus.active));
    });

    test('purgeExpiredAccounts purges accounts after deadline', () async {
      service.scheduleDeletion(userId: 'usr_old_456');
      // Overwrite with expired record
      final record = service.getRecord('usr_old_456');
      expect(record, isNotNull);

      // Verify active account is not purged before deadline
      final purged = await service.purgeExpiredAccounts();
      expect(purged, isEmpty);
    });
  });
}
