import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../controllers/rewards_controller.dart';

/// The lime profile frame (level 5 reward, features/10 §5.2; #147): a ring around [child]
/// (an avatar) when [userId] has it equipped. Works in both themes (primary accent).
class RewardFrame extends ConsumerStatefulWidget {
  final String? userId;
  final Widget child;

  const RewardFrame({super.key, required this.userId, required this.child});

  @override
  ConsumerState<RewardFrame> createState() => _RewardFrameState();
}

class _RewardFrameState extends ConsumerState<RewardFrame> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(RewardFrame old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) _ensure();
  }

  void _ensure() {
    final id = widget.userId;
    if (id != null) ref.read(frameDirectoryProvider.notifier).ensure(id);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.userId;
    final framed = id != null && (ref.watch(frameDirectoryProvider.select((m) => m[id])) ?? false);
    if (!framed) return widget.child;
    return Container(
      key: const Key('reward_frame'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: TellyColors.primaryAccentOf(context), width: 2),
      ),
      child: widget.child,
    );
  }
}

/// The "Noir" card style (level 10 reward, #147): renders [child] in greyscale when [enabled].
class NoirFilter extends StatelessWidget {
  final bool enabled;
  final Widget child;
  const NoirFilter({super.key, required this.enabled, required this.child});

  /// Rec. 709 luminance into every channel, with a touch of contrast.
  static const _matrix = <double>[
    0.2326, 0.7152, 0.0722, 0, -8, //
    0.2326, 0.7152, 0.0722, 0, -8, //
    0.2326, 0.7152, 0.0722, 0, -8, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) =>
      enabled ? ColorFiltered(colorFilter: const ColorFilter.matrix(_matrix), child: child) : child;
}
