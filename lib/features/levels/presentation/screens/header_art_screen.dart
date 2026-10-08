import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../auth/data/auth_repository.dart';
import '../../domain/level_models.dart';
import '../controllers/rewards_controller.dart';

/// Header art picker (`/more/level/rewards/header-art`, features/10 §5.2; #148): choose a still
/// from your God tier (9.20+) to show behind your profile, or remove it.
class HeaderArtScreen extends ConsumerStatefulWidget {
  const HeaderArtScreen({super.key});

  @override
  ConsumerState<HeaderArtScreen> createState() => _HeaderArtScreenState();
}

class _HeaderArtScreenState extends ConsumerState<HeaderArtScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    HapticsService.selectionClick();
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text("Couldn't change that. Try again.")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(headerArtControllerProvider);
    final me = ref.watch(authRepositoryProvider).currentUserId;
    final current = me == null ? null : ref.watch(headerArtProvider(me)).valueOrNull;
    final ctrl = ref.read(headerArtControllerProvider.notifier);
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: 'Header art',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.levelRewards),
      ),
      body: SafeArea(
        child: async.when(
          data: (choices) => choices.isEmpty
              ? const Center(
                  child: TellyEmptyState(
                    key: Key('header_art_empty'),
                    icon: Icons.landscape_rounded,
                    title: 'No stills yet',
                    message: 'Rank a title 9.20 or higher and its still can sit behind your profile.',
                  ),
                )
              : ListView(
                  key: const Key('header_art_list'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text('A still from your God tier, shown behind your profile.',
                        style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))),
                    const SizedBox(height: 14),
                    for (final art in choices) ...[
                      _ArtTile(
                        art: art,
                        selected: art == current,
                        onTap: _busy || art == current ? null : () => _run(() => ctrl.choose(art)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (current != null)
                      TextButton(
                        key: const Key('header_art_remove'),
                        onPressed: _busy ? null : () => _run(ctrl.remove),
                        child: Text('Remove header art',
                            style: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context))
                                .copyWith(fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
          loading: () => Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
          error: (_, __) => Center(
            child: TellyEmptyState(
              key: const Key('header_art_error'),
              icon: Icons.landscape_rounded,
              title: "Couldn't load your God tier",
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(headerArtControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtTile extends StatelessWidget {
  final HeaderArt art;
  final bool selected;
  final VoidCallback? onTap;
  const _ArtTile({required this.art, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${art.title}${selected ? ', current header' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('header_art_${art.mediaType}_${art.titleId}'),
        onTap: onTap,
        child: Container(
          height: 120,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? accent : TellyColors.strokeOf(context), width: selected ? 2 : 1),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PosterImage(
                posterPath: TmdbImages.backdrop(art.backdropPath),
                fallback: ColoredBox(color: TellyColors.cardOf(context)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 44,
                bottom: 10,
                child: Text(art.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.bodyLarge(color: const Color(0xFFFFFFFF)).copyWith(fontWeight: FontWeight.w800)),
              ),
              if (selected)
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                    child: const Icon(Icons.check_rounded, size: 18, color: TellyColors.backgroundPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
