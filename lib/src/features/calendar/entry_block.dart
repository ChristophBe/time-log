import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../domain/timeline/day_timeline.dart';
import '../../domain/timeline/invariants.dart';

/// One entry drawn on the calendar (SPEC §8.2).
///
/// The block is the activity: its body is the activity's fill and its left edge
/// is the activity's spine, the same colour that identifies it in the running
/// band and in the suggestion list. The spine also does the work a border used
/// to: two touching blocks of similar hue stay told apart by their edges rather
/// than by an outline drawn round everything.
///
/// Labels drop out progressively as the block gets shorter -- duration first,
/// then the name -- but the full text always stays in the semantics label, so
/// nothing is lost to a screen reader just because the block is thin.
///
/// Every adjustment available by dragging an edge is also available here by
/// keyboard and by the semantics increase/decrease actions (SPEC §10.1, §10.4).
class EntryBlock extends StatelessWidget {
  const EntryBlock({
    required this.segment,
    required this.activityName,
    required this.colorSeed,
    required this.height,
    required this.use24h,
    required this.now,
    required this.step,
    this.onTap,
    this.onAdjustStart,
    this.onAdjustEnd,
    this.selected = false,
    super.key,
  });

  final EntrySegment segment;
  final String activityName;
  final int colorSeed;
  final double height;
  final bool use24h;
  final DateTime now;

  /// One keyboard or stepper nudge, the snap interval.
  final Duration step;

  final VoidCallback? onTap;
  final void Function(Duration delta)? onAdjustStart;
  final void Function(Duration delta)? onAdjustEnd;
  final bool selected;

  /// An edge the entry carries on past is drawn open: square, and with no
  /// hairline of air under it.
  ///
  /// The running entry's bottom is the one that matters — it has not happened
  /// yet, and a rounded cap sitting a pixel clear of the now-line says it
  /// finished there. Squared and flush, it runs into the line instead, which is
  /// what "still going" looks like (SPEC §8.2). The same rule covers an entry
  /// clipped by midnight: a cut edge is not a cap.
  bool get _openBottom => segment.isRunning || segment.continuesAfter;
  bool get _openTop => segment.continuesBefore;

  /// How tall one line of [style] is for this reader.
  ///
  /// Measured rather than assumed: the thresholds used to be two pixel
  /// constants, which meant that at 200% text a block tall enough for "one
  /// line" by those numbers was not tall enough for the line itself, and the
  /// label overflowed its own block (SPEC §10.2).
  static double _lineHeight(BuildContext context, TextStyle? style) =>
      MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 12) * 1.35;

  @override
  Widget build(BuildContext context) {
    final colors = ActivityPalette.forSeed(
      colorSeed,
      Theme.of(context).brightness,
    );
    final theme = Theme.of(context).textTheme;

    // Labels drop out in order of what can be recovered elsewhere: the
    // duration is also in the sheet and in the semantics label, the name is
    // also in the semantics label, and the colour spine survives both.
    final markerLine = segment.continuesBefore || segment.continuesAfter
        ? _lineHeight(context, theme.labelSmall) *
              ((segment.continuesBefore ? 1 : 0) +
                  (segment.continuesAfter ? 1 : 0))
        : 0.0;
    final nameLine = _lineHeight(context, theme.labelLarge);
    final durationLine = _lineHeight(context, theme.bodySmall);
    const vertical = 2.0 + Strokes.hairline;
    final showsName = height >= markerLine + nameLine + vertical;
    final showsDuration =
        height >= markerLine + nameLine + durationLine + vertical;
    final showsPucks = selected && showsName && onAdjustEnd != null;

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
      hint: onTap == null ? null : 'Double tap to edit',
      button: onTap != null,
      selected: selected,
      // Increase and decrease move the end of the entry, which is how a screen
      // reader resizes a block without a drag (SPEC §10.4). The value is the
      // duration, so the reader announces the new length after each nudge.
      value: onAdjustEnd == null ? null : formatDurationVerbose(fullDuration),
      onIncrease: onAdjustEnd == null ? null : () => onAdjustEnd!(step),
      onDecrease: onAdjustEnd == null ? null : () => onAdjustEnd!(-step),
      increasedValue: onAdjustEnd == null
          ? null
          : formatDurationVerbose(fullDuration + step),
      decreasedValue: onAdjustEnd == null
          ? null
          : formatDurationVerbose(
              fullDuration - step < kMinEntryLength
                  ? kMinEntryLength
                  : fullDuration - step,
            ),
      child: Padding(
        // A hairline of air under every block, so two entries sharing a
        // boundary read as two entries. Inside the block's own box, so the
        // calendar's geometry is untouched: an hour is still an hour tall.
        // Not under an open edge, which has to meet the now-line exactly.
        padding: EdgeInsets.only(bottom: _openBottom ? 0 : Strokes.hairline),
        child: Material(
          color: colors.fill,
          clipBehavior: Clip.antiAlias,
          animationDuration: Motion.of(context, Motion.quick),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: _openTop ? Radius.zero : Radii.sm,
              bottom: _openBottom ? Radius.zero : Radii.sm,
            ),
            // Selection is live: this is the block you are acting on now
            // (SPEC §9.8).
            side: selected
                ? BorderSide(
                    color: AppColors.from(context).live,
                    width: Strokes.focus,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: <Widget>[
                // Inset and rounded, so it reads as a mark *on* the block
                // rather than as the block's border.
                Positioned(
                  left: Insets.xs,
                  top: Insets.xs,
                  bottom: Insets.xs,
                  width: Strokes.spine,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.edge,
                      borderRadius: Radii.pill,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.xs + Strokes.spine + Insets.sm,
                    1,
                    Insets.sm,
                    1,
                  ),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (segment.continuesBefore)
                          _Marker(symbol: '↑', color: colors.onFill),
                        if (showsName)
                          Text(
                            activityName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.labelLarge?.copyWith(
                              color: colors.onFill,
                            ),
                          ),
                        if (showsDuration)
                          Text(
                            '${formatTimeOfDay(start, use24h: use24h)} – '
                            '${end == null ? 'now' : formatTimeOfDay(end, use24h: use24h)}'
                            '   ${formatDuration(fullDuration)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.numeric(theme.bodySmall)
                                ?.copyWith(color: colors.onFill),
                          ),
                        if (segment.continuesAfter)
                          _Marker(symbol: '↓', color: colors.onFill),
                      ],
                    ),
                  ),
                ),
                if (showsPucks)
                  _Pucks(color: colors.onFill, hasTop: onAdjustStart != null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The grab points, shown once a block is selected or focused.
///
/// Decoration only, and deliberately not interactive: the real targets are the
/// whole top and bottom halves of the block, which is what keeps a resize
/// reachable on a block only eighteen pixels tall. Adding a tappable node here
/// would add an unlabelled one (SPEC §10.4).
class _Pucks extends StatelessWidget {
  const _Pucks({required this.color, required this.hasTop});

  final Color color;
  final bool hasTop;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: <Widget>[
        if (hasTop) Align(alignment: Alignment.topCenter, child: _puck(color)),
        Align(alignment: Alignment.bottomCenter, child: _puck(color)),
      ],
    ),
  );

  static Widget _puck(Color color) => Container(
    width: 28,
    height: 3,
    margin: const EdgeInsets.symmetric(vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.5),
      borderRadius: Radii.pill,
    ),
  );
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
