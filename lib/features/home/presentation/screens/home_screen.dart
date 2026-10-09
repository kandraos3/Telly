import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/telly_log_fab.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../providers/home_providers.dart';
import '../widgets/home_hero_card.dart';
import '../widgets/home_moves_section.dart';

/// `SCR-21` Home (epic #45, decision 0011): the landing tab. A Tonight hero for what to watch next, up to four
/// one-tap moves, and one Friends line. Nothing else lives here: your canon is in the Canon tab and the full feed
/// in Social. Spec: `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` `SCR-21`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: _RefreshWhenShown(
        child: TellyFloatingHeaderScrollView(
          header: TellyScreenHeader(
            title: 'Home',
            actions: [
              const HomeStreakChip(),
              TellyHeaderAction(
                key: const Key('home_search_button'),
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onPressed: () => context.go(Routes.exploreSearch()),
              ),
            ],
          ),
          // The header's safe area clears the nav bar; the end space lets the last row scroll above the Log button.
          body: const SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(top: 8, bottom: 24 + TellyLogFab.clearance),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeHeroSection(),
                HomeMovesSection(),
                HomeFriendsLine(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Re-derives Home's moves when the tab is shown again or the app resumes (`SCR-21` §21.6), so they never change
/// while you are looking at them. An inactive tab has its tickers off, which is how it is told apart here.
class _RefreshWhenShown extends ConsumerStatefulWidget {
  const _RefreshWhenShown({required this.child});

  final Widget child;

  @override
  ConsumerState<_RefreshWhenShown> createState() => _RefreshWhenShownState();
}

class _RefreshWhenShownState extends ConsumerState<_RefreshWhenShown> with WidgetsBindingObserver {
  bool? _active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (_active == false && active) _refresh();
    _active = active;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active != false) _refresh();
  }

  void _refresh() => Future.microtask(() {
        if (mounted) ref.read(homeStateProvider.notifier).refresh();
      });

  @override
  Widget build(BuildContext context) => widget.child;
}
