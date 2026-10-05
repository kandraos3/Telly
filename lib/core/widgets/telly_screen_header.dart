import 'package:flutter/material.dart';

import '../services/haptics_service.dart';
import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// Shared header for the four tab screens: Feed, Explore, Queue and Canon (FE-HEADER-01).
///
/// A large sentence-case title with no emoji, and up to three muted icon actions on the
/// right. Pushed screens use the one-step-smaller [TellySubpageAppBar] (FE-HEADER-02).
/// Spec: `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §0.
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
                  style: TellyTypography.screenTitle(color: TellyColors.textPrimaryOf(context)),
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

/// How a pushed screen is left: back for screens you drill into, close for tasks you dismiss.
enum TellyNavKind { back, close }

/// The one back / close button used by every pushed screen (FE-HEADER-02).
class TellyNavButton extends StatelessWidget {
  final TellyNavKind kind;

  /// Defaults to [Navigator.maybePop].
  final VoidCallback? onPressed;

  const TellyNavButton({super.key, this.kind = TellyNavKind.back, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final back = kind == TellyNavKind.back;
    return IconButton(
      tooltip: back ? 'Back' : 'Close',
      icon: Icon(back ? Icons.arrow_back_rounded : Icons.close_rounded, color: TellyColors.textPrimaryOf(context)),
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// App bar for every pushed (non-tab) screen (FE-HEADER-02): back or close on the left, a
/// left-aligned sentence-case title one step below [TellyScreenHeader], and muted actions.
/// At most one action may be accented (the screen's primary action, e.g. Save or Follow);
/// destructive actions go in a [TellyHeaderMenu]. It stays put while the content scrolls.
class TellySubpageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;

  /// A quiet second line under the title, e.g. "5 members".
  final String? subtitle;
  final TellyNavKind nav;
  final Key? navKey;
  final VoidCallback? onNav;
  final List<Widget> actions;
  final Color? backgroundColor;

  const TellySubpageAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.nav = TellyNavKind.back,
    this.navKey,
    this.onNav,
    this.actions = const [],
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(TellyScreenHeader.height);

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final subtitle = this.subtitle;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor ?? TellyColors.canvasOf(context),
      leading: TellyNavButton(key: navKey, kind: nav, onPressed: onNav),
      titleSpacing: 4,
      title: title == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Separate nodes, so each line is announced (and contrast-checked) on its own.
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    title,
                    key: const Key('subpage_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.subpageTitle(color: TellyColors.textPrimaryOf(context)),
                  ),
                ),
                if (subtitle != null)
                  Semantics(
                    container: true,
                    child: Text(
                      subtitle,
                      key: const Key('subpage_subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context)),
                    ),
                  ),
              ],
            ),
      actions: [...actions, const SizedBox(width: 4)],
    );
  }
}

/// Muted ⋮ overflow menu for header actions, home of destructive ones (FE-HEADER-02).
class TellyHeaderMenu<T> extends StatelessWidget {
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;

  const TellyHeaderMenu({super.key, this.tooltip = 'More options', required this.itemBuilder, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      color: TellyColors.cardOf(context),
      icon: Icon(Icons.more_vert_rounded, color: TellyColors.textSecondaryOf(context)),
      onSelected: onSelected,
      itemBuilder: itemBuilder,
    );
  }
}
