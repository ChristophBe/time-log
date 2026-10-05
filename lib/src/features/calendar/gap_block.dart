import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../../app/theme.dart';
import '../../core/formatters.dart';

/// Untracked time, drawn rather than hidden (SPEC §4.7, §8.2).
///
/// A shallow recess in the day with a sparse hatch over it: enough to read as
/// "nothing was recorded here" and not as a rendering fault, and quiet enough
/// that a day with many short gaps is still a day you can read. The hatch it
/// replaced was the same weight as the hour rules and eight pixels apart, which
/// made every gap the loudest thing on the screen.
class GapBlock extends StatelessWidget {
  const GapBlock({
    required this.duration,
    required this.startLocal,
    required this.endLocal,
    required this.use24h,
    this.onTap,
    super.key,
  });

  final Duration duration;
  final DateTime startLocal;
  final DateTime endLocal;
  final bool use24h;

  /// Fills the gap with an entry covering exactly it (SPEC §8.2).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.from(context);
    return Semantics(
      label:
          'Untracked, ${formatTimeOfDay(startLocal, use24h: use24h)} to '
          '${formatTimeOfDay(endLocal, use24h: use24h)}, '
          '${formatDurationVerbose(duration)}',
      hint: onTap == null ? null : 'Double tap to add an entry',
      button: onTap != null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Strokes.hairline),
        child: CustomPaint(
          painter: _GapPainter(
            recess: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
            hatch: colors.gapStroke.withValues(alpha: 0.35),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: Radii.smAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm,
                vertical: 1,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${formatDuration(duration)} untracked',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppType.numeric(Theme.of(context).textTheme.labelSmall)
                      ?.copyWith(color: colors.gapInk),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GapPainter extends CustomPainter {
  const _GapPainter({required this.recess, required this.hatch});

  final Color recess;
  final Color hatch;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(Offset.zero & size, Radii.sm);
    canvas
      ..drawRRect(shape, Paint()..color = recess)
      ..save()
      ..clipRRect(shape);

    final paint = Paint()
      ..color = hatch
      ..strokeWidth = Strokes.hairline;
    const spacing = 12.0;
    for (var x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GapPainter old) =>
      old.recess != recess || old.hatch != hatch;
}
