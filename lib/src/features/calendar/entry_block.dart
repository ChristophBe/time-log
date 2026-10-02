import 'package:flutter/material.dart';

import '../../app/palette.dart';
import '../../core/formatters.dart';
import '../../domain/timeline/day_timeline.dart';

/// One entry drawn on the calendar (SPEC §8.2).
///
/// Labels drop out progressively as the block gets shorter -- duration first,
/// then the name -- but the full text always stays in the semantics label, so
/// nothing is lost to a screen reader just because the block is thin.
class EntryBlock extends StatelessWidget {
  const EntryBlock({
    required this.segment,
    required this.activityName,
    required this.colorSeed,
    required this.height,
    required this.use24h,
    required this.now,
    this.onTap,
    this.selected = false,
    super.key,
  });

  final EntrySegment segment;
  final String activityName;
  final int colorSeed;
  final double height;
  final bool use24h;
  final DateTime now;
  final VoidCallback? onTap;
  final bool selected;

  bool get _showsName => height >= 28;
  bool get _showsDuration => height >= 44;

  @override
  Widget build(BuildContext context) {
    final colors = ActivityPalette.forSeed(
      colorSeed,
      Theme.of(context).brightness,
    );
    final fullDuration = segment.fullDuration(now);
    final start = segment.entry.startUtc.toLocal();
    final end = segment.entry.endUtc?.toLocal();

    final label = semanticEntryLabel(
      activityName: activityName,
      startLocal: start,
      endLocal: end,
      duration: fullDuration,
      use24h: use24h,
      isRunning: segment.isRunning,
    );

    return Semantics(
      label: segment.continuesBefore || segment.continuesAfter
          ? '$label, continues outside this day'
          : label,
      button: onTap != null,
      selected: selected,
      child: Material(
        color: colors.fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: selected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (segment.continuesBefore)
                    _Marker(symbol: '↑', color: colors.onFill),
                  if (_showsName)
                    Text(
                      activityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: colors.onFill),
                    ),
                  if (_showsDuration)
                    Text(
                      '${formatTimeOfDay(start, use24h: use24h)} - '
                      '${end == null ? 'now' : formatTimeOfDay(end, use24h: use24h)}'
                      '  ${formatDurationCompact(fullDuration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onFill),
                    ),
                  if (segment.continuesAfter)
                    _Marker(symbol: '↓', color: colors.onFill),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.symbol, required this.color});

  final String symbol;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    symbol,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
  );
}
