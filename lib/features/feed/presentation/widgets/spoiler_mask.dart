import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';

/// `SCR-06` spoiler mask: a frosted `BackdropFilter` (blur σ 8, i.e. CSS `blur(8px)`) over
/// the text. Tap reveals; tap again re-blurs. Reveal state is purely visual.
class SpoilerMask extends StatefulWidget {
  final String id;
  final Widget child;

  const SpoilerMask({super.key, required this.id, required this.child});

  static const blurSigma = 8.0;

  @override
  State<SpoilerMask> createState() => _SpoilerMaskState();
}

class _SpoilerMaskState extends State<SpoilerMask> {
  bool _revealed = false;

  void _toggle() {
    HapticsService.lightImpact();
    setState(() => _revealed = !_revealed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('spoiler_mask_${widget.id}'),
      onTap: _toggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: TellyColors.backgroundCard,
              child: widget.child,
            ),
            if (!_revealed)
              Positioned.fill(
                child: BackdropFilter(
                  key: Key('spoiler_blur_${widget.id}'),
                  filter: ImageFilter.blur(sigmaX: SpoilerMask.blurSigma, sigmaY: SpoilerMask.blurSigma),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_off_rounded, color: TellyColors.warmAmber, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'TAP TO REVEAL SPOILER',
                            style: TellyTypography.caption(color: TellyColors.warmAmber)
                                .copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
