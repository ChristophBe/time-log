import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/day_totals.dart';
import '../../domain/timeline/day_window.dart';

part 'today_providers.g.dart';

@Riverpod(keepAlive: true)
DayWindowCalculator dayWindows(Ref ref) => const LocalDayWindowCalculator();

/// The day the calendar is showing. Defaults to today.
@riverpod
class SelectedDay extends _$SelectedDay {
  @override
  DayWindow build() => ref
      .watch(dayWindowsProvider)
      .containing(ref.watch(appClockProvider).nowUtc());

  void goTo(DayWindow window) => state = window;

  void goToDate(DateTime localDate) => state = ref
      .read(dayWindowsProvider)
      .forDate(localDate.year, localDate.month, localDate.day);

  void nextDay() => state = ref.read(dayWindowsProvider).next(state);

  void previousDay() => state = ref.read(dayWindowsProvider).previous(state);

  void today() => state = ref
      .read(dayWindowsProvider)
      .containing(ref.read(appClockProvider).nowUtc());

  bool get isToday => state.contains(ref.read(appClockProvider).nowUtc());
}

@riverpod
Stream<TimeEntry?> runningEntry(Ref ref) =>
    ref.watch(timeEntryRepositoryProvider).watchRunningEntry();

@riverpod
Stream<Map<String, Activity>> activitiesById(Ref ref) =>
    ref.watch(timeEntryRepositoryProvider).watchActivitiesById();

/// Entries touching the selected day, oldest first. An entry crossing midnight
/// appears here for both days it touches (SPEC §5.3).
@riverpod
Stream<List<TimeEntry>> dayEntries(Ref ref) {
  final window = ref.watch(selectedDayProvider);
  return ref
      .watch(timeEntryRepositoryProvider)
      .watchEntriesInRange(window.startUtc, window.endUtc);
}

/// Recomputed on the 30-second tick rather than every second, so the day view
/// does not rebuild once per second (SPEC §11.4).
@riverpod
DayTotals dayTotals(Ref ref) {
  final window = ref.watch(selectedDayProvider);
  final entries = ref.watch(dayEntriesProvider).value ?? const <TimeEntry>[];
  final now =
      ref.watch(coarseTickerProvider).value ??
      ref.watch(appClockProvider).nowUtc();
  return computeDayTotals(entries: entries, window: window, now: now);
}

@riverpod
Stream<List<ActivitySuggestion>> activitySuggestions(Ref ref, String query) {
  final running = ref.watch(runningEntryProvider).value;
  return ref
      .watch(timeEntryRepositoryProvider)
      .watchSuggestions(
        now: ref.watch(appClockProvider).nowUtc(),
        query: query,
        excludeActivityId: running?.activityId,
      );
}

/// The most recent finished entry, for "Resume" when nothing is running.
@riverpod
Future<TimeEntry?> lastFinishedEntry(Ref ref) {
  // Re-read whenever the timeline changes.
  ref.watch(runningEntryProvider);
  ref.watch(dayEntriesProvider);
  return ref.watch(timeEntryRepositoryProvider).lastFinishedEntry();
}
