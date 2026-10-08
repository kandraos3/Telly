import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../controllers/explore_rows_controller.dart';
import '../widgets/explore_rows_view.dart';

/// SCR-07 See all (#181), at `/explore/row/:rowId?canon=movie|tv`: one Explore row as a grid,
/// ranked from the same payload as the carousel (features/07 §7.5).
class ExploreRowScreen extends ConsumerWidget {
  const ExploreRowScreen({super.key, required this.rowId, required this.mediaType});

  final String rowId;

  /// `movie` or `tv`; anything else is an unknown canon.
  final String? mediaType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canon = mediaType;
    if (canon != 'movie' && canon != 'tv') return const _Unavailable();
    final async = ref.watch(exploreRowsProvider(canon!));
    final state = async.valueOrNull;
    if (state == null) {
      if (async.hasError) return const _Unavailable();
      return Scaffold(
        appBar: TellySubpageAppBar(onNav: () => context.pop()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final row = state.rows.isNewUser ? null : state.rows.rowById(rowId);
    if (row == null) return const _Unavailable();
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: ExploreRowGrid.titleOf(row, canon),
        subtitle: ExploreRowGrid.subtitleOf(row, canon),
        onNav: () => context.pop(),
      ),
      body: ExploreRowGrid(row: row, mediaType: canon, today: ref.watch(exploreNowProvider)()),
    );
  }
}

/// An unknown row or canon, or a row today's picks no longer have.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TellySubpageAppBar(onNav: () => context.pop()),
      body: Center(
        key: const Key('explore_row_unavailable'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            "This list isn't available",
            textAlign: TextAlign.center,
            style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
          ),
        ),
      ),
    );
  }
}
