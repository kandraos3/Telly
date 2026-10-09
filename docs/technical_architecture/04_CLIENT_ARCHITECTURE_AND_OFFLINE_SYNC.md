# Technical Architecture Spec 04: Client Architecture, Riverpod & Offline-First Sync

## 1. Clean Feature-Driven Project Structure

The mobile application is organized using a scalable **Feature-First Architecture**:

```
lib/
├── app.dart                          # Root MaterialApp & Theme definitions
├── main.dart                         # Entry point, Sentry initialization
│
├── core/                             # Shared foundation & services
│   ├── constants/                    # Color tokens, typography, asset paths
│   ├── network/                      # Dio HTTP client, interceptors, auth headers
│   ├── database/                     # Drift SQLite local tables, migrations
│   ├── router/                       # GoRouter navigation & deep-link parser
│   ├── theme/                        # Midnight Cathode theme & haptics engine
│   └── utils/                        # Spearman correlation math, date formatters
│
└── features/                         # Independent functional feature domains
    ├── auth/                         # Splash, Social Auth, Handle claim
    │   ├── data/                     # AuthRepository (Supabase GoTrue)
    │   ├── domain/                   # UserProfile model, AuthSession
    │   └── presentation/             # LoginScreen, HandleClaimScreen
    │
    ├── ranking_engine/               # The Beli Duel & Logging Studio
    │   ├── data/                     # RankingRepository, DuelController
    │   ├── domain/                   # DuelState, BinarySearchAlgorithm
    │   └── presentation/             # DuelArenaScreen, SentimentSheet, RevealModal
    │
    ├── canon/                        # Personal Leaderboard & Multi-Views
    │   ├── data/                     # Local Rankings SQLite cache
    │   └── presentation/             # RankedListTab, TierViewTab, GridTab
    │
    ├── social_feed/                  # Timeline, Upsets, Reactions & Comments
    ├── co_watching/                  # Two-to-Watch decider, Rapid Swipe
    ├── smart_queue/                  # Watchlist & JustWatch availability
    └── settings/                     # Subscriptions, Notifications, Exports
```

---

## 2. State Management Architecture: Riverpod 2.x

Telly utilizes **Flutter Riverpod (with Code Generation)**. State flows unidirectionally, with complete separation between business logic and UI presentation.

### 2.1 The Duel Arena State Machine (`AsyncNotifier`)

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'duel_controller.g.dart';

@freezed
class DuelState with _$DuelState {
  const factory DuelState({
    required Show showToInsert,
    required List<Show> userCanonSnapshot,
    required int lowBound,
    required int highBound,
    required int currentComparisonIndex,
    required int roundNumber,
    required bool isComplete,
    required int? finalRankSlot,
  }) = _DuelState;
}

@riverpod
class DuelController extends _$DuelController {
  @override
  DuelState build(Show showToInsert, SentimentBracket initialBracket) {
    final existingCanon = ref.read(canonRepositoryProvider).getCachedCanon();
    
    // 1. Calculate initial binary boundaries based on sentiment bracket
    final bounds = _calculateBracketBounds(existingCanon.length, initialBracket);
    final initialMid = (bounds.low + bounds.high) ~/ 2;

    return DuelState(
      showToInsert: showToInsert,
      userCanonSnapshot: existingCanon,
      lowBound: bounds.low,
      highBound: bounds.high,
      currentComparisonIndex: initialMid,
      roundNumber: 1,
      isComplete: existingCanon.isEmpty,
      finalRankSlot: existingCanon.isEmpty ? 1 : null,
    );
  }

  void chooseWinner({required bool candidateWon}) {
    final current = state;
    if (current.isComplete) return;

    int newLow = current.lowBound;
    int newHigh = current.highBound;

    if (candidateWon) {
      // Candidate is better than comparison item -> search higher half
      newHigh = current.currentComparisonIndex - 1;
    } else {
      // Candidate is worse than comparison item -> search lower half
      newLow = current.currentComparisonIndex + 1;
    }

    if (newLow > newHigh) {
      // Binary search complete: exact rank slot determined!
      final targetRank = newLow + 1; // 1-indexed
      state = current.copyWith(
        isComplete: true,
        finalRankSlot: targetRank,
      );
      
      // Trigger background sync to commit ranking
      ref.read(rankingRepositoryProvider).commitRanking(
        show: current.showToInsert,
        rank: targetRank,
      );
    } else {
      final nextMid = (newLow + newHigh) ~/ 2;
      state = current.copyWith(
        lowBound: newLow,
        highBound: newHigh,
        currentComparisonIndex: nextMid,
        roundNumber: current.roundNumber + 1,
      );
    }
  }
}
```

---

## 3. Offline-First Sync Engine (Drift SQLite)

To ensure the user never waits on a network spinner when organizing their personal canon, all mutations are **optimistic and local-first**.

```
[ User Ranks Show ] 
         │
         ▼
[ Write to Local SQLite with status = PENDING_SYNC ]
         │
         ▼
[ Instant 0ms UI Rebalance ] ── User sees updated canon immediately
         │
         ▼
[ Background Sync Worker ]
    ├── If Online: Flush batch to Supabase via RPC
    │              Mark record as SYNCED
    └── If Offline: Retry on connectivity change listener
```

### 3.1 Local SQLite Table Definition (Drift)
```dart
import 'package:drift/drift.dart';

class LocalRankings extends Table {
  IntColumn get showId => integer()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  IntColumn get rankOrder => integer()();
  RealColumn get calculatedScore => real()();
  TextColumn get status => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))(); // 'SYNCED', 'PENDING'
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {showId};
}
```

### 3.2 Pending mutation kinds
The write-ahead log (`PendingMutations`) is replayed in strict FIFO order by the sync engine, each row calling one server RPC with its `client_mutation_id` so a replay is a no-op (I-5). The kinds, in `MutationKind`:

| Kind | Server call |
| :--- | :--- |
| `log_title`, `move`, `delete`, `duels`, `editorial` | Ranking RPCs and the editorial update (TA-02 §3.2). |
| `watchlist_add`, `watchlist_remove` | `user_watchlist` upsert and delete. |
| `tracking_start`, `tracking_place`, `tracking_rewatch`, `tracking_finish`, `tracking_stop`, `tracking_revive` | `start_tracking`, `set_tracking_place`, `log_episode_rewatch`, `finish_tracking`, `stop_tracking`, `revive_dropped_show` (TA-02 §3.6, features/11 §9.2). Payloads carry **absolute places**, so replays converge on the last write; an Undo is just another `tracking_place` with the earlier place. |

Watch tracking also keeps two Drift caches (schema version 5): `TrackingCache` (one row per tracked title, mirroring `get_my_tracking`) and `EpisodeCache` (one JSON document per season, refetched after 7 days). On reconnect, `get_my_tracking` replaces every `TrackingCache` row that has no pending mutation; rows with pending mutations keep their local copy until they are acknowledged.

---

## 4. Off-Screen 1080x1920 Story Card Pipeline

Rendering crisp 9:16 graphics for Instagram and TikTok without displaying them on the user's screen:

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

class StoryCardRenderer {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<Uint8List> generateTop9Story({
    required List<Show> top9Shows,
    required String username,
  }) async {
    // Invisibly paints widget tree at fixed 1080x1920 resolution
    final Uint8List imageBytes = await _screenshotController.captureFromWidget(
      Top9StoryWidget(shows: top9Shows, username: username),
      targetSize: const Size(1080, 1920),
      pixelRatio: 1.0,
      context: null,
      delay: const Duration(milliseconds: 100), // Ensures posters decode
    );

    return imageBytes;
  }
}
```

---

## 5. Performance Budgets & 120Hz Rendering

- **Impeller Engine:** Pre-compiles all shaders at build time to completely eliminate runtime jank / shader compilation stutter.
- **Image RAM Ceiling:** `CachedNetworkImage` memory cache is strictly capped at **64 MB** in RAM; older images are flushed to disk to prevent out-of-memory (OOM) crashes on older mobile devices.
- **List Virtualization:** Rankings lists of 300+ shows use `ListView.builder` with `itemExtent: 88.0` for constant-time layout measurement.
