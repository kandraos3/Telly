import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/home/domain/friends_line.dart';

import 'home_fixtures.dart';

// SCR-21 §21.4: the one-line friends summary.
void main() {
  FriendsLineData? line(List<ActivityLog> feed, {String? me = 'me'}) =>
      FriendsLine.from(feed: feed, me: me, now: homeNow);

  test('nothing from friends is no line', () {
    expect(line(const []), isNull);
    expect(line([friendActivity('Me', userId: 'me')]), isNull, reason: 'own posts are left out');
    expect(line([friendActivity('Maya', type: ActivityType.medalUnlocked)]), isNull);
    expect(line([friendActivity('Maya', type: ActivityType.challengeCompleted)]), isNull);
  });

  test('counts today\'s rankings and names the friends', () {
    final data = line([
      for (var i = 0; i < 9; i++)
        friendActivity('F$i', userId: 'u$i', titleId: i, age: Duration(minutes: 10 + i)),
    ])!;
    expect(data.meta, 'ranked 9 titles today');
    expect(data.title, 'F0, F1 and 7 others');
    expect(data.faces, hasLength(3));
    expect(data.faces.first.name, 'F0');
  });

  test('phrases one, two and three friends', () {
    expect(line([friendActivity('Maya')])!.title, 'Maya');
    expect(line([friendActivity('Maya'), friendActivity('Jordan', userId: 'u2')])!.title, 'Maya and Jordan');
    final three = line([
      friendActivity('Maya'),
      friendActivity('Jordan', userId: 'u2'),
      friendActivity('Sam', userId: 'u3'),
    ])!;
    expect(three.title, 'Maya, Jordan and 1 other');
  });

  test('counts distinct titles, and a lone title reads singular', () {
    final data = line([
      friendActivity('Maya', age: const Duration(hours: 1)),
      friendActivity('Maya', age: const Duration(hours: 2), type: ActivityType.upsetAlert),
    ])!;
    expect(data.meta, 'ranked 1 title today');
  });

  test('yesterday\'s rankings do not count as today', () {
    final data = line([friendActivity('Maya', age: const Duration(hours: 20))])!;
    expect(data.meta, startsWith('ranked Andor #2'));
  });

  test('with no rankings today it shows the newest item\'s sentence', () {
    final data = line([
      friendActivity('Maya', type: ActivityType.watchStarted, title: 'Severance', rank: null, age: const Duration(hours: 2)),
      friendActivity('Sam', userId: 'u3', type: ActivityType.queueAdded, title: 'Dune', age: const Duration(days: 1)),
    ])!;
    expect(data.title, 'Maya');
    expect(data.meta, 'started watching Severance · 2h');
    expect(data.faces, hasLength(1));
  });

  test('a friend without a display name shows their @username', () {
    expect(line([friendActivity('')])!.title, '@');
  });

  test('ago steps from minutes to days', () {
    expect(FriendsLine.ago(homeNow, homeNow), 'now');
    expect(FriendsLine.ago(homeNow.subtract(const Duration(minutes: 5)), homeNow), '5m');
    expect(FriendsLine.ago(homeNow.subtract(const Duration(hours: 3)), homeNow), '3h');
    expect(FriendsLine.ago(homeNow.subtract(const Duration(days: 2)), homeNow), '2d');
  });
}
