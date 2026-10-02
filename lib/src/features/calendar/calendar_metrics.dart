import 'dart:math' as math;

import '../../domain/models/app_settings.dart';
import '../../domain/timeline/day_window.dart';

/// Converts between instants and vertical pixels for the day calendar
/// (SPEC §8.2).
///
/// Pure and Flutter-free so the geometry can be unit-tested without laying out a
/// widget. Positions come from real instants rather than `hour * 60`, which is
/// what makes a 23- or 25-hour DST day come out right.
class CalendarMetrics {
  const CalendarMetrics({
    required this.window,
    required this.pixelsPerHour,
    this.minBlockHeight = 18,
  });

  final DayWindow window;
  final double pixelsPerHour;

  /// Shortest block the calendar will draw, so a one-minute entry stays visible
  /// and hittable (SPEC §8.2).
  final double minBlockHeight;

  double get pixelsPerMinute => pixelsPerHour / 60;

  /// Full scroll height of the day. 23 or 25 hours on a DST day.
  double get totalHeight => window.length.inMinutes * pixelsPerMinute;

  /// Vertical offset of [instantUtc], clamped to the day.
  double offsetFor(DateTime instantUtc) =>
      window.offsetOf(instantUtc).inMinutes * pixelsPerMinute;

  /// Exact height for [duration], which may be below [minBlockHeight].
  double heightFor(Duration duration) =>
      math.max(0, duration.inMinutes * pixelsPerMinute);

  /// Height to actually draw: never thinner than [minBlockHeight].
  double renderedHeightFor(Duration duration) =>
      math.max(heightFor(duration), minBlockHeight);

  /// The instant at vertical offset [dy], for drag and tap-to-create.
  DateTime instantAt(double dy) {
    final clamped = dy.clamp(0, totalHeight);
    final minutes = clamped / pixelsPerMinute;
    final instant = window.startUtc.add(
      Duration(milliseconds: (minutes * 60000).round()),
    );
    if (instant.isBefore(window.startUtc)) return window.startUtc;
    if (instant.isAfter(window.endUtc)) return window.endUtc;
    return instant;
  }

  /// Hour boundaries inside the day, as real instants.
  ///
  /// On a spring-forward day the local labels jump (01:00 then 03:00) because the
  /// hour genuinely did not exist; on a fall-back day a local hour appears twice.
  /// Both are correct, and both come for free from stepping in real time.
  List<DateTime> hourTicks() {
    final ticks = <DateTime>[];
    for (
      var tick = window.startUtc;
      tick.isBefore(window.endUtc);
      tick = tick.add(const Duration(hours: 1))
    ) {
      ticks.add(tick);
    }
    return ticks;
  }

  /// Whether there is room to draw the half-hour hairlines (SPEC §8.2).
  bool get showsHalfHours => pixelsPerHour >= 100;

  CalendarMetrics withZoom(double newPixelsPerHour) => CalendarMetrics(
    window: window,
    pixelsPerHour: newPixelsPerHour.clamp(
      AppSettings.minPixelsPerHour,
      AppSettings.maxPixelsPerHour,
    ),
    minBlockHeight: minBlockHeight,
  );
}
