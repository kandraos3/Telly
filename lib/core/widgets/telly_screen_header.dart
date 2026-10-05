import 'package:flutter/material.dart';

import '../services/haptics_service.dart';
import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// Shared header for the four tab screens: Feed, Explore, Queue and Canon (FE-HEADER-01).
///
/// A large sentence-case title with no emoji, and up to three muted icon actions on the
/// right. Spec: `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §0.
class TellyScreenHeader extends StatelessWidget {
  static const height = 56.0;

  final String title;

  /// At most three, usually [TellyHeaderAction]s; they vary per screen (and per mode on Queue).
  final List<Widget> actions;

  const TellyScreenHeader({super.key, required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      // 4 dp on the right puts the last icon glyph 16 dp from the edge (48 dp target, 24 dp glyph).
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  key: const Key('screen_header_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.titleLarge(color: TellyColors.textPrimaryOf(context)).copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// A muted 48 dp icon button for [TellyScreenHeader.actions].
class TellyHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const TellyHeaderAction({super.key, required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: TellyColors.textSecondaryOf(context)),
      onPressed: onPressed == null
          ? null
          : () {
              HapticsService.selectionClick();
              onPressed();
            },
    );
  }
}

/// Puts [header] above [body] and hides it while the body scrolls down; any upward
/// scroll snaps it back, wherever the body is (FE-HEADER-01).
///
/// The body's vertical scroll views must not have their own [ScrollController]: they
/// attach to the [PrimaryScrollController] that [NestedScrollView] provides.
class TellyFloatingHeaderScrollView extends StatelessWidget {
  final TellyScreenHeader header;
  final Widget body;

  const TellyFloatingHeaderScrollView({super.key, required this.header, required this.body});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            primary: false,
            floating: true,
            snap: true,
            automaticallyImplyLeading: false,
            toolbarHeight: TellyScreenHeader.height,
            titleSpacing: 0,
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: TellyColors.canvasOf(context),
            surfaceTintColor: Colors.transparent,
            title: header,
          ),
        ],
        body: body,
      ),
    );
  }
}
