import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/telly_colors.dart';

/// Modal bottom sheet with frosted dark acrylic glassmorphic surface and drag handle.
/// Conforms to `docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §6.
class TellyFrostedSheet extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;
  final bool showDragHandle;

  const TellyFrostedSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.9,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xD9141419), // rgba(20, 20, 25, 0.85)
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: TellyColors.borderGlass,
              width: 1.0,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TellyColors.strokeStrong, // #3D435C
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Convenience helper to present a modal bottom sheet wrapped in [TellyFrostedSheet].
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: TellyColors.backgroundPrimary.withValues(alpha: 0.8),
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (ctx) => TellyFrostedSheet(
        child: builder(ctx),
      ),
    );
  }
}

