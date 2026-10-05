import '../../ranking/data/ranking_repository.dart';

/// What the `SCR-12` "Share to Instagram Story" asset shows (FE-SHARE-01).
class RevealStory {
  final String title;
  final String canonLabel;
  final int rank;
  final int total;
  final double score;
  final String tierLabel;
  final List<RevealLeaderboardEntry> leaderboard;

  const RevealStory({
    required this.title,
    required this.canonLabel,
    required this.rank,
    required this.total,
    required this.score,
    required this.tierLabel,
    this.leaderboard = const [],
  });

  String get caption => 'I just ranked $title #$rank in my $canonLabel on Telly 📺';
}
