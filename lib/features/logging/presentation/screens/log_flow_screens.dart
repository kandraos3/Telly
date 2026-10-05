import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../ranking/data/ranking_repository.dart';
import '../../../ranking/domain/canon_tier.dart';
import '../../../ranking/domain/canon_type.dart';
import '../../../sharing/data/story_share_service.dart';
import '../../../sharing/domain/reveal_story.dart';
import '../../data/title_repository.dart';
import '../../../ranking/presentation/controllers/duel_controller.dart';
import '../../../ranking/presentation/screens/duel_arena_screen.dart';
import '../../../ranking/presentation/screens/slot_reveal_modal.dart';
import '../../../ranking/presentation/widgets/editorial_tagging_sheet.dart';
import '../controllers/logging_session_controller.dart';

/// Sends a deep link into the middle of the flow back to `SCR-09` (no draft to continue).
void _restartLogging(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      try {
        context.go(Routes.log);
      } catch (_) {}
    }
  });
}

/// `SCR-10` → `SCR-11` for the current logging draft (FE-604).
///
/// The duel commits the placement; the editorial sheet then attaches tags/MVP/review and the
/// flow continues to `SCR-12`.
class LogDuelScreen extends ConsumerStatefulWidget {
  const LogDuelScreen({super.key});

  @override
  ConsumerState<LogDuelScreen> createState() => _LogDuelScreenState();
}

class _LogDuelScreenState extends ConsumerState<LogDuelScreen> {
  bool _completed = false;

  Future<void> _onComplete(DuelComplete result) async {
    if (_completed) return;
    _completed = true;
    final commit = result.commit;
    ref.read(loggingSessionProvider.notifier).recordCommit(commit);
    final isAnime = ref.read(loggingSessionProvider).title?.isAnime ?? false;
    final credits = await ref
        .read(titleRepositoryProvider)
        .fetchCredits(commit.candidate.titleId, commit.candidate.mediaType);
    if (!mounted) return;

    final editorial = await EditorialTaggingSheet.show(
      context: context,
      title: commit.candidate.title,
      mediaType: commit.candidate.mediaType,
      targetRank: commit.rank,
      totalInCanon: commit.total,
      isAnime: isAnime,
      director: credits.director,
      castMembers: credits.cast,
    );
    if (editorial != null) {
      await ref.read(rankingRepositoryProvider).attachEditorial(
            titleId: commit.candidate.titleId,
            mediaType: commit.candidate.mediaType,
            data: editorial,
          );
    }
    if (mounted) context.pushReplacement(Routes.reveal);
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(loggingSessionProvider.select((d) => d.duelRequest));
    if (request == null) {
      _restartLogging(context);
      return const Scaffold(backgroundColor: TellyColors.backgroundPrimary);
    }
    return DuelArenaScreen(
      request: request,
      onCancel: () => context.pop(),
      onDuelComplete: _onComplete,
    );
  }
}

/// `SCR-12` for the committed placement (FE-604).
class LogRevealScreen extends ConsumerWidget {
  const LogRevealScreen({super.key});

  /// Renders the 9:16 reveal story and hands it to the OS share sheet (FE-SHARE-01).
  Future<void> _shareStory(BuildContext context, WidgetRef ref, RankingCommit commit) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(storyShareServiceProvider).shareRankReveal(RevealStory(
            title: commit.candidate.title,
            canonLabel: CanonType.fromMediaType(commit.candidate.mediaType) == CanonType.movie
                ? 'Movie Canon'
                : 'Series Canon',
            rank: commit.rank,
            total: commit.total,
            score: commit.score,
            tierLabel: CanonTier.fromScore(commit.score).label,
            leaderboard: commit.leaderboard(),
          ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't create your story. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commit = ref.watch(loggingSessionProvider.select((d) => d.commit));
    if (commit == null) {
      _restartLogging(context);
      return const Scaffold(backgroundColor: TellyColors.backgroundPrimary);
    }
    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      body: SlotRevealModal(
        showId: commit.candidate.titleId,
        title: commit.candidate.title,
        mediaType: commit.candidate.mediaType,
        posterPath: commit.candidate.posterPath,
        rankPosition: commit.rank,
        totalInCanon: commit.total,
        targetScore: commit.score,
        beatingTitles: commit.beating(),
        justBehindTitles: [if (commit.justBehind != null) commit.justBehind!],
        leaderboard: commit.leaderboard(),
        onShareStory: () => _shareStory(context, ref, commit),
        onViewInCanon: () => context.go(Routes.canon),
        onClose: () => context.go(Routes.feed),
      ),
    );
  }
}
