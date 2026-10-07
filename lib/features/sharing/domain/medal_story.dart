import '../../achievements/domain/medal.dart';

/// One medal on the share card (only unlocked medals are ever shared).
class MedalStoryItem {
  final String name;
  final MedalTier tier;
  final String glyph;

  const MedalStoryItem({required this.name, required this.tier, required this.glyph});

  factory MedalStoryItem.of(Medal m) => MedalStoryItem(name: m.name, tier: m.tier, glyph: m.glyph);
}

/// What the medals share card shows (Template E, viral sharing spec §2; features/10 §4.4, §9.4).
///
/// Two layouts: a single medal ("ACHIEVEMENT UNLOCKED", from the unlock moment and the medal
/// sheet) or a set of up to three (the profile showcase, from `SCR-23`'s Share).
class MedalStory {
  final String heading;
  final List<MedalStoryItem> medals;

  /// Under a single medal: its personal line. Under a set: "12 of 14 medals unlocked".
  final String line;

  /// "Unlocked by 4.2% of Telly viewers", for a single medal.
  final String? rarity;
  final String caption;

  const MedalStory({
    required this.heading,
    required this.medals,
    required this.line,
    this.rarity,
    required this.caption,
  });

  bool get isSingle => medals.length == 1;

  factory MedalStory.single(Medal medal) => MedalStory(
        heading: 'Achievement unlocked',
        medals: [MedalStoryItem.of(medal)],
        line: medal.personalLine,
        rarity: medal.rarityIsNew ? null : medal.rarityLine,
        caption: 'I unlocked the ${medal.name} medal on Telly 🏅',
      );

  factory MedalStory.showcase(MedalShowcase showcase, {required int unlocked, required int total}) => MedalStory(
        heading: showcase.isRecent ? 'My latest medals' : 'My pinned medals',
        medals: [for (final m in showcase.medals) MedalStoryItem.of(m)],
        line: '$unlocked of $total medals unlocked',
        caption: 'My medals on Telly 🏅',
      );
}
