import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../today/today_providers.dart';
import 'calendar_metrics.dart';
import 'calendar_providers.dart';
import 'entry_block.dart';
import 'gap_block.dart';
import 'now_line.dart';

/// The day as a vertical timeline (SPEC §8.2).
class DayCalendar extends ConsumerStatefulWidget {
  const DayCalendar({this.onEntryTap, this.selectedEntryId, super.key});

  final void Function(TimeEntry entry)? onEntryTap;
  final String? selectedEntryId;

  @override
  ConsumerState<DayCalendar> createState() => DayCalendarState();
}

class DayCalendarState extends ConsumerState<DayCalendar> {
  final _scrollController = ScrollController();
  bool _hasScrolledToStart = false;
  double _zoomAtGestureStart = 0;

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
          child: SizedBox(
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
                  Positioned(
                    top: metrics.offsetFor(segment.startUtc),
                    left: gutter,
                    right: 8,
                    height: metrics.renderedHeightFor(segment.visibleDuration),
                    child: EntryBlock(
                      key: ValueKey<String>('block-${segment.entry.id}'),
                      segment: segment,
                      activityName:
                          activities[segment.entry.activityId]?.name ??
                          'Activity',
                      colorSeed:
                          activities[segment.entry.activityId]?.colorSeed ?? 0,
                      height: metrics.renderedHeightFor(
                        segment.visibleDuration,
                      ),
                      use24h: settings.use24HourClock,
                      now: now,
                      selected: widget.selectedEntryId == segment.entry.id,
                      onTap: widget.onEntryTap == null
                          ? null
                          : () => widget.onEntryTap!(segment.entry),
                    ),
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
              ],
            ),
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
