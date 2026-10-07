import 'package:telly_app/features/challenges/data/challenges_repository.dart';
import 'package:telly_app/features/challenges/domain/challenge.dart';

/// The clock every challenge test runs at: Wednesday 2026-10-07 12:00 local.
final testNow = DateTime(2026, 10, 7, 12);

Challenge challenge(
  String slug, {
  String? name,
  String description = 'Rank 8 horror films by Oct 31',
  String art = 'horror',
  String glyph = '8',
  int daysLeft = 24,
  bool openEnded = false,
  bool ended = false,
  int target = 8,
  bool featured = false,
  String? squad,
  int participants = 2140,
  int friends = 3,
  bool joined = false,
  int progress = 0,
  bool completed = false,
}) =>
    Challenge(
      id: 'id-$slug',
      slug: slug,
      name: name ?? slug,
      description: description,
      art: art,
      medalGlyph: glyph,
      startsAt: testNow.subtract(const Duration(days: 6)),
      endsAt: openEnded
          ? null
          : ended
              ? testNow.subtract(const Duration(days: 2))
              : testNow.add(Duration(days: daysLeft) - const Duration(hours: 1)),
      target: target,
      featured: featured,
      squadId: squad == null ? null : 'squad-$squad',
      squadName: squad,
      participantCount: participants,
      friendCount: friends,
      joined: joined,
      myProgress: progress,
      completedAt: completed ? testNow.subtract(const Duration(days: 3)) : null,
    );

/// Mockup C1: Spooktober featured (joined, 3 of 8), two of mine, two to join, one ended.
List<Challenge> sampleMine() => [
      challenge('spooktober', name: 'Spooktober', featured: true, joined: true, progress: 3),
      challenge('batman-marathon', name: 'The Batman marathon', art: 'noir', glyph: 'B', joined: true, progress: 4,
          openEnded: true),
      challenge('a24-month', name: 'A24 month', art: 'noir', glyph: 'A24', squad: 'Couch Potatoes', target: 20,
          joined: true, progress: 11),
      challenge('summer-heat', name: 'Summer Heat', ended: true, joined: true, progress: 8, completed: true),
    ];

List<Challenge> sampleDiscover() => [
      challenge('best-picture-decade', name: 'Best Picture decade', description: 'Every winner 2015–2024',
          art: 'gold', openEnded: true, friends: 0),
      challenge('miniseries-november', name: 'Miniseries November', description: '4 limited series in 30 days',
          art: 'violet', target: 4, daysLeft: 30),
    ];

class FakeChallengesRepository implements ChallengesRepository {
  FakeChallengesRepository({List<Challenge>? mine, List<Challenge>? discover})
      : mineList = mine ?? sampleMine(),
        discoverList = discover ?? sampleDiscover();

  List<Challenge> mineList;
  List<Challenge> discoverList;
  Object? error;
  final joined = <String>[];
  final left = <String>[];
  List<ChallengeRacer> racerList = const [];
  List<ChallengePick> pickList = const [];
  List<ChallengeTemplate> templateList = const [
    ChallengeTemplate(key: 'genre_month', name: 'Genre month', params: ['genre'], target: 8),
    ChallengeTemplate(key: 'limited_series', name: 'Limited series run', target: 5),
  ];
  final created = <Map<String, Object?>>[];

  @override
  Future<List<Challenge>> mine() async {
    if (error != null) throw error!;
    return mineList;
  }

  @override
  Future<List<Challenge>> discover() async {
    if (error != null) throw error!;
    return discoverList;
  }

  @override
  Future<Challenge?> bySlug(String slug) async =>
      [...mineList, ...discoverList].where((c) => c.slug == slug).firstOrNull;

  @override
  Future<int> join(String challengeId) async {
    joined.add(challengeId);
    final c = discoverList.firstWhere((c) => c.id == challengeId);
    discoverList = [for (final d in discoverList) if (d.id != challengeId) d];
    mineList = [...mineList, c.copyWith(joined: true, myProgress: 1)];
    return 1;
  }

  @override
  Future<void> leave(String challengeId) async => left.add(challengeId);

  @override
  Future<List<ChallengeRacer>> racers(String challengeId) async => racerList;

  @override
  Future<List<ChallengePick>> picks(String challengeId) async => pickList;

  @override
  Future<List<ChallengeTemplate>> templates() async => templateList;

  @override
  Future<Challenge?> createSquadChallenge({
    required String squadId,
    required String templateKey,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
    Map<String, Object> params = const {},
    int? target,
  }) async {
    created.add({'squad': squadId, 'template': templateKey, 'name': name, 'params': params,
        'days': endsAt.difference(startsAt).inDays});
    return null;
  }
}
