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
  /// Whether the view is still tracking the real day rather than sitting on one
  /// that was chosen. Only a tracking view is carried across midnight, which is
  /// the whole distinction [followNow] needs and the window alone cannot tell
  /// you: "yesterday, navigated to at 23:50" and "today, five minutes later"
  /// are the same window (SPEC §8.2).
  bool _followsToday = true;

  @override
  DayWindow build() => ref
      .watch(dayWindowsProvider)
      .containing(ref.watch(appClockProvider).nowUtc());

  void goTo(DayWindow window) {
    _followsToday = false;
    state = window;
  }

  void goToDate(DateTime localDate) {
    _followsToday = false;
    state = ref
        .read(dayWindowsProvider)
        .forDate(localDate.year, localDate.month, localDate.day);
  }

  void nextDay() {
    _followsToday = false;
    state = ref.read(dayWindowsProvider).next(state);
  }

  void previousDay() {
    _followsToday = false;
    state = ref.read(dayWindowsProvider).previous(state);
  }

  void today() {
    _followsToday = true;
    state = ref
        .read(dayWindowsProvider)
        .containing(ref.read(appClockProvider).nowUtc());
  }

  /// Carries a tracking view across midnight (SPEC §8.2, §9.3).
  ///
  /// Without this the day stays on yesterday once the clock passes midnight:
  /// the now-line leaves the window, the total stops moving, and the entry
  /// §6.11 has just started is on a day that is not on screen.
  void followNow() {
    if (!_followsToday) return;
    final now = ref.read(appClockProvider).nowUtc();
    if (state.contains(now)) return;
    state = ref.read(dayWindowsProvider).containing(now);
  }

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

/// When the current run began, following back through the entries SPEC §6.11
/// cut apart at midnight -- so a clock left on overnight reports eight hours
/// rather than however long it is since 00:00 (SPEC §8.1).
///
/// An instant and not a duration, so the 30-second tick does not drag a
/// database walk behind it: this changes only when the timeline does, and the
/// banner measures against now itself.
@riverpod
Future<DateTime?> runStartUtc(Ref ref) {
  final running = ref.watch(runningEntryProvider).value;
  if (running == null) return Future<DateTime?>.value();
  return ref
      .watch(timeEntryRepositoryProvider)
      .runStartOf(running, days: ref.watch(dayWindowsProvider));
}

/// The most recent finished entry, for "Resume" when nothing is running.
@riverpod
Future<TimeEntry?> lastFinishedEntry(Ref ref) {
  // Re-read whenever the timeline changes.
  ref.watch(runningEntryProvider);
  ref.watch(dayEntriesProvider);
  return ref.watch(timeEntryRepositoryProvider).lastFinishedEntry();
}
