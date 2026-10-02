import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/day_timeline.dart';
import '../../domain/timeline/invariants.dart';
import '../../domain/timeline/timeline_math.dart';
import '../../domain/timeline_writer.dart';
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
  const DayCalendar({this.onEntryTap, this.selectedEntryId, super.key});

  final void Function(TimeEntry entry)? onEntryTap;
  final String? selectedEntryId;

  @override
  ConsumerState<DayCalendar> createState() => DayCalendarState();
}

class DayCalendarState extends ConsumerState<DayCalendar> {
  final _scrollController = ScrollController();
  final _stackKey = GlobalKey();
  bool _hasScrolledToStart = false;
  double _zoomAtGestureStart = 0;
  _DragState? _drag;

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
    final target = (metrics.offsetFor(focus) - 120).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  double _gutterWidth(BuildContext context) {
    // Grows with the text scale so hour labels are never clipped (SPEC §10.2).
    final scaled = MediaQuery.textScalerOf(context).scale(12);
    return (scaled * 4.2).clamp(52.0, 140.0);
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
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          // Dragging a boundary must not also scroll the view.
          physics: _drag == null ? null : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            key: _stackKey,
            height: metrics.totalHeight,
            child: Stack(
              children: <Widget>[
                _HourRules(
                  metrics: metrics,
                  gutter: gutter,
                  use24h: settings.use24HourClock,
                ),
                for (final gap in timeline.gaps)
                  Positioned(
                    top: metrics.offsetFor(gap.startUtc),
                    left: gutter,
                    right: 8,
                    height: metrics.renderedHeightFor(gap.duration),
                    child: GapBlock(
                      duration: gap.duration,
                      startLocal: gap.startUtc.toLocal(),
                      endLocal: gap.endUtc.toLocal(),
                      use24h: settings.use24HourClock,
                    ),
                  ),
                for (final segment in timeline.segments)
                  _positionedSegment(
                    segment: segment,
                    metrics: metrics,
                    preview: preview,
                    now: now,
                    gutter: gutter,
                    settings: settings,
                    step: step,
                    activities: activities,
                  ),
                if (metrics.window.contains(now))
                  Positioned(
                    top: metrics.offsetFor(now) - 1,
                    left: 0,
                    right: 8,
                    child: NowLine(
                      label: formatTimeOfDay(
                        now.toLocal(),
                        use24h: settings.use24HourClock,
                      ),
                      gutterWidth: gutter,
                    ),
                  ),
                if (preview != null)
                  Positioned(
                    top: metrics.offsetFor(preview.applied) - 10,
                    left: gutter,
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

    return Positioned(
      key: ValueKey<String>('slot-${entry.id}'),
      top: metrics.offsetFor(times.start),
      left: gutter,
      right: 8,
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
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: scheme.onInverseSurface),
          ),
        ),
      ),
    );
  }
}

class _HourRules extends StatelessWidget {
  const _HourRules({
    required this.metrics,
    required this.gutter,
    required this.use24h,
  });

  final CalendarMetrics metrics;
  final double gutter;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        for (final tick in metrics.hourTicks())
          Positioned(
            top: metrics.offsetFor(tick),
            left: 0,
            right: 0,
            child: ExcludeSemantics(
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: gutter,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        formatTimeOfDay(tick.toLocal(), use24h: use24h),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 1, color: scheme.outlineVariant),
                  ),
                ],
              ),
            ),
          ),
        if (metrics.showsHalfHours)
          for (final tick in metrics.hourTicks())
            Positioned(
              top: metrics.offsetFor(tick.add(const Duration(minutes: 30))),
              left: gutter,
              right: 0,
              child: Container(
                height: 1,
                color: scheme.surfaceContainerHighest,
              ),
            ),
      ],
    );
  }
}
