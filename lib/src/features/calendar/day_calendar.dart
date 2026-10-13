import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/platform_style.dart';
import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/clustering.dart';
import '../../domain/timeline/day_timeline.dart';
import '../../domain/timeline/invariants.dart';
import '../../domain/timeline/timeline_math.dart';
import '../../domain/timeline_writer.dart';
import 'fill_gap_sheet.dart';
import '../today/action_feedback.dart';
import '../today/resume_action.dart';
import '../today/today_providers.dart';
import 'calendar_metrics.dart';
import 'calendar_providers.dart';
import 'entry_block.dart';
import 'gap_block.dart';
import 'now_line.dart';

/// A boundary being dragged.
class _DragState {
  const _DragState({
    required this.entryId,
    required this.edge,
    required this.desiredUtc,
    required this.grabOffsetPx,
  });

  final String entryId;
  final BoundaryEdge edge;
  final DateTime desiredUtc;

  /// How far the finger was from the boundary when it grabbed it.
  ///
  /// Kept so the edge does not jump to the finger on pickup: you grabbed a
  /// point, and the boundary should move by as much as you move, not snap to
  /// wherever you happened to press.
  final double grabOffsetPx;

  _DragState withDesired(DateTime instant) => _DragState(
    entryId: entryId,
    edge: edge,
    desiredUtc: instant,
    grabOffsetPx: grabOffsetPx,
  );
}

/// The day as a vertical timeline (SPEC §8.2), with boundaries draggable per
/// SPEC §7.
class DayCalendar extends ConsumerStatefulWidget {
  const DayCalendar({
    this.onEntryTap,
    this.selectedEntryId,
    this.topInset = 0,
    super.key,
  });

  final void Function(TimeEntry entry)? onEntryTap;
  final String? selectedEntryId;

  /// Empty space above midnight, so that the day can scroll *under* a floating
  /// header instead of starting below it (SPEC §9.8). Outside the axis's own
  /// box, so none of the geometry in `CalendarMetrics` knows about it.
  final double topInset;

  @override
  ConsumerState<DayCalendar> createState() => DayCalendarState();
}

class DayCalendarState extends ConsumerState<DayCalendar> {
  final _scrollController = ScrollController();
  final _stackKey = GlobalKey();
  bool _hasScrolledToStart = false;
  double _zoomAtGestureStart = 0;
  _DragState? _drag;

  /// Which cluster of too-short entries has been opened, if any (SPEC §8.2).
  String? _expandedCluster;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Opens on the now-line for today, or on the day's first entry for a past
  /// day, rather than always at midnight (SPEC §8.2).
  void _scrollToInterestingPoint(CalendarMetrics metrics, DateTime now) {
    if (_hasScrolledToStart || !_scrollController.hasClients) return;
    _hasScrolledToStart = true;

    final window = metrics.window;
    final focus = window.contains(now)
        ? now
        : (ref.read(dayTimelineProvider).segments.firstOrNull?.startUtc ??
              window.startUtc);
    // Plus the inset, because the content now starts that far down: without it
    // the first scroll would land the now-line a header's height too low.
    final target = (metrics.offsetFor(focus) - 120 + widget.topInset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  double _gutterWidth(BuildContext context) {
    // Grows with the text scale so hour labels are never clipped (SPEC §10.2).
    final scaled = MediaQuery.textScalerOf(context).scale(12);
    return (scaled * 4.2).clamp(Metrics.gutterBase, Metrics.gutterMax);
  }

  // ------------------------------------------------------------------ dragging

  /// The vertical position of [global] in the calendar's own coordinates.
  double? _axisDy(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.globalToLocal(global).dy;
  }

  /// Converts a global drag position into an instant on the axis, allowing for
  /// where on the boundary the finger first landed.
  DateTime? _instantAtGlobal(
    Offset global,
    CalendarMetrics metrics, {
    double grabOffsetPx = 0,
  }) {
    final dy = _axisDy(global);
    if (dy == null) return null;
    return metrics.instantAt(dy - grabOffsetPx);
  }

  /// Which boundary a long press grabbed: the top half takes the start, the
  /// bottom half the end. A long press rather than a plain drag, because a plain
  /// vertical drag belongs to the scroll view.
  BoundaryEdge _edgeFor(Offset localPosition, double blockHeight) =>
      localPosition.dy < blockHeight / 2
      ? BoundaryEdge.start
      : BoundaryEdge.end;

  /// The move the current drag would commit, computed with the same pure
  /// function the writer uses, so the preview cannot disagree with the result.
  BoundaryMove? _previewMove({
    required DayTimeline timeline,
    required AppSettings settings,
    required DateTime now,
  }) {
    final drag = _drag;
    if (drag == null) return null;
    final index = timeline.segments.indexWhere(
      (s) => s.entry.id == drag.entryId,
    );
    if (index < 0) return null;
    try {
      return resolveBoundaryMove(
        target: timeline.segments[index].entry,
        edge: drag.edge,
        desired: drag.desiredUtc,
        prev: index > 0 ? timeline.segments[index - 1].entry : null,
        next: index < timeline.segments.length - 1
            ? timeline.segments[index + 1].entry
            : null,
        snap: settings.snap,
        now: now,
      );
    } on InvariantViolation {
      return null;
    }
  }

  Future<void> _commitDrag(Duration snap) async {
    final drag = _drag;
    setState(() => _drag = null);
    if (drag == null) return;
    await _moveBoundary(
      entryId: drag.entryId,
      edge: drag.edge,
      desired: drag.desiredUtc,
      snap: snap,
    );
  }

  /// Single path for every boundary change: drag, keyboard and the semantics
  /// increase/decrease actions all end up here, so they cannot diverge.
  Future<void> _moveBoundary({
    required String entryId,
    required BoundaryEdge edge,
    required DateTime desired,
    required Duration snap,
  }) async {
    final writer = ref.read(timelineWriterProvider);
    try {
      final outcome = await writer.moveBoundary(
        entryId: entryId,
        edge: edge,
        desired: desired,
        snap: snap,
      );
      if (outcome.wasClamped) await HapticFeedback.selectionClick();
      if (!mounted) return;
      showUndoableFeedback(
        context,
        message:
            '${edge == BoundaryEdge.start ? 'Start' : 'End'} moved to '
            '${formatTimeOfDay(outcome.appliedUtc.toLocal(), use24h: true)}',
        undo: outcome.undo,
      );
    } on InvariantViolation catch (error) {
      if (!mounted) return;
      showUndoableFeedback(context, message: error.detail, undo: null);
    }
  }

  /// SPEC §8.2: a gap is tappable, and filling it covers exactly the gap.
  Future<void> _fillGap(DateTime startUtc, DateTime endUtc, bool use24h) async {
    final name = await showFillGapSheet(
      context,
      startLocal: startUtc.toLocal(),
      endLocal: endUtc.toLocal(),
      duration: endUtc.difference(startUtc),
      use24h: use24h,
    );
    if (name == null || !mounted) return;
    try {
      final undo = await ref
          .read(timelineWriterProvider)
          .insertEntry(name: name, startUtc: startUtc, endUtc: endUtc);
      if (!mounted) return;
      showUndoableFeedback(context, message: 'Added $name', undo: undo);
    } on InvariantViolation catch (error) {
      if (!mounted) return;
      showUndoableFeedback(context, message: error.detail, undo: null);
    }
  }

  Future<void> _delete(TimeEntry entry) async {
    final undo = await ref.read(timelineWriterProvider).delete(entry.id);
    if (!mounted) return;
    showUndoableFeedback(context, message: 'Entry deleted', undo: undo);
  }

  /// The times to draw a segment with, honouring an in-flight drag preview.
  ({DateTime start, DateTime end}) _drawnTimes(
    EntrySegment segment,
    BoundaryMove? preview,
    DateTime now,
    CalendarMetrics metrics,
  ) {
    var start = segment.startUtc;
    var end = segment.endUtc;
    final changed = preview?.changedEntries.where(
      (e) => e.id == segment.entry.id,
    );
    if (changed != null && changed.isNotEmpty) {
      final updated = changed.first;
      start = updated.startUtc;
      end = updated.endUtc ?? now;
    }
    final window = metrics.window;
    if (start.isBefore(window.startUtc)) start = window.startUtc;
    if (end.isAfter(window.endUtc)) end = window.endUtc;
    if (!end.isAfter(start)) end = start.add(const Duration(minutes: 1));
    return (start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(calendarMetricsProvider);
    final timeline = ref.watch(dayTimelineProvider);
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final now =
        ref.watch(coarseTickerProvider).value ??
        ref.watch(appClockProvider).nowUtc();
    final gutter = _gutterWidth(context);
    final step = settings.snap > Duration.zero
        ? settings.snap
        : const Duration(minutes: 1);
    final preview = _previewMove(
      timeline: timeline,
      settings: settings,
      now: now,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToInterestingPoint(metrics, now),
    );

    return GestureDetector(
      // Two fingers zoom; one finger is left to the scroll view. Zoom buttons
      // exist too, so this is never the only way (SPEC §10.1).
      onScaleStart: (_) => _zoomAtGestureStart = metrics.pixelsPerHour,
      onScaleUpdate: (details) {
        if (details.pointerCount < 2) return;
        ref
            .read(calendarZoomProvider.notifier)
            .setTo(_zoomAtGestureStart * details.verticalScale);
      },
      // Each platform draws its own: Cupertino's is thinner, rounder and fades
      // the way an Apple user expects (SPEC §9.8).
      child: _PlatformScrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(top: widget.topInset),
          // Dragging a boundary must not also scroll the view.
          physics: _drag == null ? null : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            key: _stackKey,
            height: metrics.totalHeight,
            child: Stack(
              children: <Widget>[
                _Axis(
                  metrics: metrics,
                  gutter: gutter,
                  use24h: settings.use24HourClock,
                ),
                for (final gap in timeline.gaps)
                  Positioned(
                    top: metrics.offsetFor(gap.startUtc),
                    left: gutter,
                    right: Insets.sm,
                    height: metrics.renderedHeightFor(gap.duration),
                    // A gap only takes taps once it is big enough to be a legal
                    // target (SPEC §10.2). Below that the honest answer is to
                    // zoom in — which is already the answer for short entries
                    // (SPEC §8.2) — rather than to offer a four-pixel button.
                    child: GapBlock(
                      duration: gap.duration,
                      startLocal: gap.startUtc.toLocal(),
                      endLocal: gap.endUtc.toLocal(),
                      use24h: settings.use24HourClock,
                      onTap:
                          widget.onEntryTap == null ||
                              metrics.renderedHeightFor(gap.duration) <
                                  kMinTapTarget
                          ? null
                          : () => _fillGap(
                              gap.startUtc,
                              gap.endUtc,
                              settings.use24HourClock,
                            ),
                    ),
                  ),
                for (final cluster in clusterSegments(
                  timeline.segments,
                  pixelsPerMinute: metrics.pixelsPerMinute,
                  minHeight: metrics.minBlockHeight,
                ))
                  if (!cluster.isCluster || _expandedCluster == cluster.id)
                    for (final segment in cluster.segments)
                      _positionedSegment(
                        segment: segment,
                        metrics: metrics,
                        preview: preview,
                        now: now,
                        gutter: gutter,
                        settings: settings,
                        step: step,
                        activities: activities,
                      )
                  else
                    Positioned(
                      top: metrics.offsetFor(cluster.first.startUtc),
                      left: gutter,
                      right: Insets.sm,
                      height: metrics.minBlockHeight,
                      child: _ShortEntriesChip(
                        count: cluster.segments.length,
                        onTap: () =>
                            setState(() => _expandedCluster = cluster.id),
                      ),
                    ),
                if (metrics.window.contains(now))
                  Positioned(
                    top: metrics.offsetFor(now),
                    left: 0,
                    right: Insets.sm,
                    // The line sits at the centre of the row that carries the
                    // pill, so the row has to be lifted by half its own height
                    // for the line to land on the instant. Half of *its own*
                    // height, which only it knows: the pill grows with the text
                    // scale. Positioned it by the row's top instead, and the
                    // line drew itself nine pixels into the future — the same
                    // mistake the hour rules used to make, and the reason the
                    // running block could never quite reach it.
                    child: FractionalTranslation(
                      translation: const Offset(0, -0.5),
                      child: NowLine(
                        label: formatTimeOfDay(
                          now.toLocal(),
                          use24h: settings.use24HourClock,
                        ),
                        gutterWidth: gutter,
                      ),
                    ),
                  ),
                if (preview != null)
                  Positioned(
                    top: metrics.offsetFor(preview.applied) - 12,
                    left: Insets.sm,
                    child: _DragReadout(
                      label: formatTimeOfDay(
                        preview.applied.toLocal(),
                        use24h: settings.use24HourClock,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionedSegment({
    required EntrySegment segment,
    required CalendarMetrics metrics,
    required BoundaryMove? preview,
    required DateTime now,
    required double gutter,
    required AppSettings settings,
    required Duration step,
    required Map<String, Activity> activities,
  }) {
    final times = _drawnTimes(segment, preview, now, metrics);
    final height = metrics.renderedHeightFor(times.end.difference(times.start));
    final entry = segment.entry;
    final canEdit = widget.onEntryTap != null;

    // A block that has not ended is pinned by its *bottom* edge, so that it
    // always meets the now-line. Pinning the top instead lets the minimum
    // rendered height (SPEC §8.2) push a just-started entry past now and draw
    // time that has not happened yet; this way the minimum is spent upwards,
    // where no line contradicts it.
    final openEnded = segment.isRunning || segment.continuesAfter;
    final top = openEnded
        ? math.max(0.0, metrics.offsetFor(times.end) - height)
        : metrics.offsetFor(times.start);

    return Positioned(
      key: ValueKey<String>('slot-${entry.id}'),
      top: top,
      left: gutter,
      right: Insets.sm,
      height: height,
      child: GestureDetector(
        // The EntryBlock below already publishes the block's semantics, including
        // the increase/decrease actions that replace this drag for anyone not
        // using one. Leaving this detector in the tree would add a second,
        // unlabelled tappable node.
        excludeFromSemantics: true,
        // Long press then drag, so a plain vertical drag still scrolls.
        onLongPressStart: !canEdit
            ? null
            : (details) {
                final edge = _edgeFor(details.localPosition, height);
                if (edge == BoundaryEdge.end && entry.isRunning) return;
                final dy = _axisDy(details.globalPosition);
                if (dy == null) return;
                final boundary = edge == BoundaryEdge.start
                    ? times.start
                    : times.end;
                final grabOffset = dy - metrics.offsetFor(boundary);
                setState(
                  () => _drag = _DragState(
                    entryId: entry.id,
                    edge: edge,
                    desiredUtc: boundary,
                    grabOffsetPx: grabOffset,
                  ),
                );
              },
        onLongPressMoveUpdate: !canEdit
            ? null
            : (details) {
                final drag = _drag;
                if (drag == null) return;
                final instant = _instantAtGlobal(
                  details.globalPosition,
                  metrics,
                  grabOffsetPx: drag.grabOffsetPx,
                );
                if (instant == null) return;
                setState(() => _drag = drag.withDesired(instant));
              },
        onLongPressEnd: !canEdit ? null : (_) => _commitDrag(settings.snap),
        onLongPressCancel: () => setState(() => _drag = null),
        child: CallbackShortcuts(
          // SPEC §10.5. These sit *above* the Focus below them on purpose: key
          // events travel from the focused node up through its ancestors, so a
          // handler underneath the focusable node would never see them.
          bindings: <ShortcutActivator, VoidCallback>{
            // Down is later in time, matching the axis.
            const SingleActivator(
              LogicalKeyboardKey.arrowUp,
              shift: true,
            ): () =>
                _adjustEnd(entry, -step, settings.snap),
            const SingleActivator(
              LogicalKeyboardKey.arrowDown,
              shift: true,
            ): () =>
                _adjustEnd(entry, step, settings.snap),
            const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
                _adjustStart(entry, -step, settings.snap),
            const SingleActivator(
              LogicalKeyboardKey.arrowDown,
              alt: true,
            ): () =>
                _adjustStart(entry, step, settings.snap),
            const SingleActivator(LogicalKeyboardKey.enter): () =>
                widget.onEntryTap?.call(entry),
            const SingleActivator(LogicalKeyboardKey.space): () {
              if (!entry.isRunning) resumeOrContinue(context, ref, entry);
            },
            const SingleActivator(LogicalKeyboardKey.delete): () =>
                _delete(entry),
            const SingleActivator(LogicalKeyboardKey.backspace): () =>
                _delete(entry),
          },
          child: Focus(
            child: Builder(
              builder: (context) => EntryBlock(
                key: ValueKey<String>('block-${entry.id}'),
                segment: segment,
                activityName: activities[entry.activityId]?.name ?? 'Activity',
                colorSeed: activities[entry.activityId]?.colorSeed ?? 0,
                height: height,
                use24h: settings.use24HourClock,
                now: now,
                step: step,
                selected:
                    widget.selectedEntryId == entry.id ||
                    _drag?.entryId == entry.id ||
                    Focus.of(context).hasFocus,
                onTap: canEdit ? () => widget.onEntryTap!(entry) : null,
                onAdjustStart: !canEdit
                    ? null
                    : (delta) => _adjustStart(entry, delta, settings.snap),
                onAdjustEnd: !canEdit || entry.isRunning
                    ? null
                    : (delta) => _adjustEnd(entry, delta, settings.snap),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Both the keyboard shortcuts and the semantics increase/decrease actions go
  /// through here, so a nudge means the same thing however it was asked for.
  void _adjustEnd(TimeEntry entry, Duration delta, Duration snap) {
    final end = entry.endUtc;
    if (end == null) return;
    _moveBoundary(
      entryId: entry.id,
      edge: BoundaryEdge.end,
      desired: end.add(delta),
      snap: snap,
    );
  }

  void _adjustStart(TimeEntry entry, Duration delta, Duration snap) =>
      _moveBoundary(
        entryId: entry.id,
        edge: BoundaryEdge.start,
        desired: entry.startUtc.add(delta),
        snap: snap,
      );
}

/// Several entries too short to draw apart, stood in for by one chip
/// (SPEC §8.2).
///
/// Without it the shorter ones are drawn *under* their neighbours — the minimum
/// block height makes them overlap rather than shrink — and become unreachable.
/// Tapping draws them individually; zooming in un-clusters them on its own,
/// because at a larger scale they no longer collide.
class _ShortEntriesChip extends StatelessWidget {
  const _ShortEntriesChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$count short entries',
      hint: 'Double tap to show them',
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ExcludeSemantics(
                child: Text(
                  '$count short entries',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The scrollbar of whichever design system is in charge.
class _PlatformScrollbar extends StatelessWidget {
  const _PlatformScrollbar({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => PlatformStyle.from(context).isApple
      ? CupertinoScrollbar(controller: controller, child: child)
      : Scrollbar(controller: controller, child: child);
}

/// The live time under the finger while dragging a boundary.
class _DragReadout extends StatelessWidget {
  const _DragReadout({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Material(
        color: scheme.inverseSurface,
        borderRadius: Radii.pill,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs / 2,
          ),
          child: Text(
            label,
            style: AppType.numeric(Theme.of(context).textTheme.labelMedium)
                ?.copyWith(color: scheme.onInverseSurface),
          ),
        ),
      ),
    );
  }
}

/// The hour axis: the labels down the gutter, the rules across the day, and
/// the spine that separates the two.
///
/// The rules are painted rather than laid out as a row per hour. A `Positioned`
/// row centres its hairline inside its own text height, which put every
/// gridline about seven pixels below the instant it claimed to mark while the
/// blocks beside it were positioned exactly -- so the axis and the day quietly
/// disagreed. A painter puts the line on the instant.
///
/// The labels stay real `Text` widgets rather than painted glyphs, so they
/// scale with the platform text size like everything else (SPEC §10.2).
class _Axis extends StatelessWidget {
  const _Axis({
    required this.metrics,
    required this.gutter,
    required this.use24h,
  });

  final CalendarMetrics metrics;
  final double gutter;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.from(context);
    // The axis is nothing but numbers, so it is set in the mono (SPEC §9.8).
    final style = AppType.numeric(Theme.of(context).textTheme.labelSmall)
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    // Enough to centre the label on its rule. The rules stop at the gutter, so
    // a label can sit level with its line without crossing it.
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 11) * 1.4;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _AxisPainter(
              metrics: metrics,
              gutter: gutter,
              rule: colors.axisRule,
              faintRule: colors.axisRuleFaint,
              spine: colors.gutterSpine,
            ),
          ),
        ),
        for (final tick in metrics.hourTicks())
          Positioned(
            // Clamped so midnight's label stays on screen instead of being
            // half cut off by the top of the day.
            top: (metrics.offsetFor(tick) - labelHeight / 2).clamp(
              0.0,
              metrics.totalHeight - labelHeight,
            ),
            left: 0,
            width: gutter,
            height: labelHeight,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(right: Insets.sm),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatTimeOfDay(tick.toLocal(), use24h: use24h),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AxisPainter extends CustomPainter {
  const _AxisPainter({
    required this.metrics,
    required this.gutter,
    required this.rule,
    required this.faintRule,
    required this.spine,
  });

  final CalendarMetrics metrics;
  final double gutter;
  final Color rule;
  final Color faintRule;
  final Color spine;

  @override
  void paint(Canvas canvas, Size size) {
    final hourPaint = Paint()
      ..color = rule
      ..strokeWidth = Strokes.hairline;
    final halfPaint = Paint()
      ..color = faintRule
      ..strokeWidth = Strokes.hairline;

    for (final tick in metrics.hourTicks()) {
      final y = metrics.offsetFor(tick) + 0.5;
      canvas.drawLine(Offset(gutter, y), Offset(size.width, y), hourPaint);
      if (!metrics.showsHalfHours) continue;
      final half =
          metrics.offsetFor(tick.add(const Duration(minutes: 30))) + 0.5;
      canvas.drawLine(
        Offset(gutter, half),
        Offset(size.width, half),
        halfPaint,
      );
    }

    // The gutter's own edge: it gives the day a spine to hang off, and makes
    // the blocks read as placed against the axis rather than floating near it.
    final spinePaint = Paint()
      ..color = spine
      ..strokeWidth = Strokes.hairline;
    canvas.drawLine(
      Offset(gutter - 0.5, 0),
      Offset(gutter - 0.5, size.height),
      spinePaint,
    );
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      old.metrics.pixelsPerHour != metrics.pixelsPerHour ||
      old.metrics.window != metrics.window ||
      old.gutter != gutter ||
      old.rule != rule ||
      old.faintRule != faintRule ||
      old.spine != spine;
}
