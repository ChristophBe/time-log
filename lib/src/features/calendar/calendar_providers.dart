import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/day_timeline.dart';
import '../today/today_providers.dart';
import 'calendar_metrics.dart';

part 'calendar_providers.g.dart';

/// Calendar zoom in pixels per hour (SPEC §8.2). Starts from the stored setting
/// and is adjusted by pinch or the zoom buttons for the session.
@riverpod
class CalendarZoom extends _$CalendarZoom {
  @override
  double build() =>
      ref.watch(appSettingsProvider).value?.pixelsPerHour ??
      const AppSettings().pixelsPerHour;

  void setTo(double pixelsPerHour) => state = pixelsPerHour.clamp(
    AppSettings.minPixelsPerHour,
    AppSettings.maxPixelsPerHour,
  );

  void scaleBy(double factor) => setTo(state * factor);

  /// One step of the zoom buttons, which exist so zooming never requires a
  /// pinch (SPEC §10.1).
  void zoomIn() => setTo(state * 1.5);

  void zoomOut() => setTo(state / 1.5);
}

/// Recomputed on the 30-second tick, not every second (SPEC §11.4).
@riverpod
DayTimeline dayTimeline(Ref ref) => buildDayTimeline(
  window: ref.watch(selectedDayProvider),
  entries: ref.watch(dayEntriesProvider).value ?? const <TimeEntry>[],
  now:
      ref.watch(coarseTickerProvider).value ??
      ref.watch(appClockProvider).nowUtc(),
);

@riverpod
CalendarMetrics calendarMetrics(Ref ref) => CalendarMetrics(
  window: ref.watch(selectedDayProvider),
  pixelsPerHour: ref.watch(calendarZoomProvider),
);
