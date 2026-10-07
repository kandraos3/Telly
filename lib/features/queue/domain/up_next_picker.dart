import 'dart:math';

/// Chooses the Queue's "Up next" title (SCR-13, epic #47, decision 0004).
///
/// For now a uniformly random pick from the pool the screen shows for one canon (after
/// the filter); a smart pick is tracked in #124. Each canon (`'movie'` / `'tv'`) keeps its
/// own pick, so switching canons and back doesn't re-roll. A pick that leaves the pool is
/// replaced at once, and [shuffle] never returns the current pick. Pure Dart: the
/// [Random] is injected so tests can seed it.
class UpNextPicker {
  UpNextPicker(this._random);

  final Random _random;
  final Map<String, int> _picks = {};

  /// The pick for [mediaType] from [pool] (title ids), or null when the pool is empty.
  /// Keeps the current pick while it is still in the pool.
  int? pickFor(String mediaType, List<int> pool) {
    if (pool.isEmpty) {
      _picks.remove(mediaType);
      return null;
    }
    final current = _picks[mediaType];
    if (current != null && pool.contains(current)) return current;
    return _picks[mediaType] = pool[_random.nextInt(pool.length)];
  }

  /// Picks a different title for [mediaType]. With fewer than two titles there is no
  /// other choice, so the current pick stands.
  int? shuffle(String mediaType, List<int> pool) {
    final current = pickFor(mediaType, pool);
    if (pool.length < 2) return current;
    final others = [for (final id in pool) if (id != current) id];
    return _picks[mediaType] = others[_random.nextInt(others.length)];
  }
}
