/// Route paths for every screen in `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`
/// (route map: §0.0, decision 0003).
abstract final class Routes {
  static const splash = '/splash';
  static const auth = '/auth'; // SCR-01
  static const resetPassword = '/reset-password'; // opened by a password recovery link

  // Onboarding (SCR-02 … SCR-04, preceded by handle reservation)
  static const onboarding = '/onboarding';
  static const handle = '/onboarding/handle';
  static const streamingSetup = '/onboarding/streaming'; // SCR-02
  static const seedGrid = '/onboarding/seeds'; // SCR-03
  static const tournament = '/onboarding/tournament'; // SCR-04

  // Shell tabs (component spec §2.1), in nav bar order
  static const home = '/home'; // SCR-21
  static const explore = '/explore'; // SCR-07
  static const canon = '/canon'; // SCR-14
  static const social = '/social'; // SCR-05
  static const more = '/more'; // SCR-22

  /// Explore with its search field focused; the token makes every request a new location.
  static String exploreSearch() => '$explore?search=${DateTime.now().microsecondsSinceEpoch}';

  // Logging flow (full-screen, outside the shell)
  static const log = '/log'; // SCR-09
  static const duel = '/log/duel'; // SCR-10 (+ SCR-11 sheet)
  static const reveal = '/log/reveal'; // SCR-12

  // Pushed screens
  static String activity(String id) => '$social/activity/$id'; // SCR-06
  static String title(String mediaType, int id) => '/title/$mediaType/$id'; // SCR-08
  static String profile(String handle) => '/u/$handle'; // SCR-15
  static String twoToWatch(String handle) => '/u/$handle/two-to-watch'; // SCR-16
  static const cowatch = '/cowatch'; // SCR-16
  static String cowatchWithTitle(int titleId, {String? mediaType, String? friendHandle}) =>
      '/cowatch?titleId=$titleId${mediaType != null ? '&mediaType=$mediaType' : ''}'
      '${friendHandle != null ? '&friend=$friendHandle' : ''}';
  static const squads = '/squads'; // SCR-17 list
  static String squad(String id) => '/squads/$id'; // SCR-17

  // Pushed from the More hub
  static const queue = '$more/queue'; // SCR-13
  static String customList(String id) => '$queue/list/$id';
  static const queueLists = '$queue/lists'; // SCR-13 Lists screen (#47)
  static const graveyard = '$more/graveyard'; // SCR-18
  static const wrapped = '$more/wrapped'; // SCR-19
  static const settings = '$more/settings'; // SCR-20
  static const editProfile = '$more/edit';

  /// Where an old (pre-#44) path now lives, keeping the rest of the path and the query; null when
  /// [uri] is not an old path. Old links in shares, notifications and emails keep working (§0.0).
  static String? legacyRedirect(Uri uri) {
    final path = uri.path;
    String? moved;
    if (path == '/feed' || path.startsWith('/feed/')) {
      moved = social + path.substring('/feed'.length);
    } else if (path == '/queue' || path.startsWith('/queue/')) {
      moved = queue + path.substring('/queue'.length);
    } else {
      for (final sub in const ['settings', 'edit', 'graveyard', 'wrapped']) {
        final old = '$canon/$sub';
        if (path == old || path.startsWith('$old/')) {
          moved = '$more/$sub${path.substring(old.length)}';
          break;
        }
      }
    }
    if (moved == null) return null;
    return uri.hasQuery ? '$moved?${uri.query}' : moved;
  }
}
