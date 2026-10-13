import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../../app/theme.dart';

/// The "you are here" line (SPEC §8.2).
///
/// Drawn in the app's one accent, which means exactly this: *now* (SPEC §9.8).
/// Not the error colour it used to borrow — nothing is wrong at 15:04 — and not
/// a colour any activity can wear, because the hue arc it lives in is struck
/// from the palette (SPEC §9.7).
///
/// Static when animations are disabled; it never pulses, because a moving line
/// is decoration and the information is in its position and label.
class NowLine extends StatelessWidget {
  const NowLine({required this.label, required this.gutterWidth, super.key});

  final String label;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.from(context);
    return IgnorePointer(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: gutterWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: Insets.xs),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.live,
                    borderRadius: Radii.pill,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppType.numeric(
                      Theme.of(context).textTheme.labelSmall,
                    )?.copyWith(color: colors.onLive),
                  ),
                ),
              ),
            ),
          ),
          // The dot marks where the line starts, so the eye picks up the line
          // at the axis instead of somewhere along it.
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.live,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(height: Strokes.now, color: colors.live),
          ),
        ],
      ),
    );
  }
}
