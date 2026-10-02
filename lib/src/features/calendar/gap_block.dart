import 'package:flutter/material.dart';

import '../../core/formatters.dart';

/// Untracked time, drawn rather than hidden (SPEC §4.7, §8.2).
///
/// Hatched instead of empty so it reads as "nothing was recorded here", not as a
/// rendering gap.
class GapBlock extends StatelessWidget {
  const GapBlock({
    required this.duration,
    required this.startLocal,
    required this.endLocal,
    required this.use24h,
    super.key,
  });

  final Duration duration;
  final DateTime startLocal;
  final DateTime endLocal;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Untracked, ${formatTimeOfDay(startLocal, use24h: use24h)} to '
          '${formatTimeOfDay(endLocal, use24h: use24h)}, '
          '${formatDurationVerbose(duration)}',
      child: CustomPaint(
        painter: _HatchPainter(color: scheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              formatDurationCompact(duration),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 8.0;
    for (var x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.color != color;
}
