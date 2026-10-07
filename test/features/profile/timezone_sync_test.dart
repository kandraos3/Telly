import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/profile/data/timezone_sync.dart';

void main() {
  group('#139 TimezoneSync', () {
    test('sends the device zone once, again only when it changes', () async {
      var zone = 'Europe/Berlin';
      final sent = <String>[];
      final sync = TimezoneSync(deviceZone: () async => zone, send: (z) async => sent.add(z));
      await sync.sync();
      await sync.sync();
      expect(sent, ['Europe/Berlin']);
      zone = 'Asia/Tokyo';
      await sync.sync();
      expect(sent, ['Europe/Berlin', 'Asia/Tokyo']);
    });

    test('a failed send is retried on the next sync; errors never escape', () async {
      var fail = true;
      final sent = <String>[];
      final sync = TimezoneSync(
        deviceZone: () async => 'America/New_York',
        send: (z) async {
          if (fail) throw Exception('offline');
          sent.add(z);
        },
      );
      await sync.sync();
      expect(sent, isEmpty);
      fail = false;
      await sync.sync();
      expect(sent, ['America/New_York']);
    });

    test('an unreadable device zone is ignored', () async {
      final sent = <String>[];
      final sync = TimezoneSync(deviceZone: () async => throw Exception('no plugin'), send: (z) async => sent.add(z));
      await sync.sync();
      expect(sent, isEmpty);
    });
  });
}
