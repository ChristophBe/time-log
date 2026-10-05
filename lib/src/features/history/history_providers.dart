import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/day_window.dart';
import '../today/today_providers.dart';

part 'history_providers.g.dart';

/// How many months of history are loaded, counting the current one (SPEC §8.5).
///
/// Paging by month rather than by row: a month is the unit people think in, it
/// is bounded (a few hundred entries at most), and the range query it needs
/// already exists and is already tested. Searching and filtering then happen in
/// Dart over what is loaded, which is why there is no second SQL query here.
@riverpod
class HistoryMonths extends _$HistoryMonths {
  @override
  int build() => 1;

  void loadEarlier() => state = state + 1;
}

/// Bumped when something asks History to start searching.
///
/// A signal rather than a shared FocusNode: SPEC §10.5 makes Cmd/Ctrl+F global,
/// so the shortcut lives in the shell — which has no business holding the
/// search field's focus node, and may not even have built History yet.
@riverpod
class HistorySearchRequest extends _$HistorySearchRequest {
  @override
  int build() => 0;

  void request() => state++;
}

/// What is typed in the search field (SPEC §8.5).
@riverpod
class HistoryQuery extends _$HistoryQuery {
  @override
  String build() => '';

  // ignore: use_setters_to_change_properties
  void set(String value) => state = value;
}

/// The activity the list is filtered to, or null for all of them.
@riverpod
class HistoryActivityFilter extends _$HistoryActivityFilter {
  @override
  String? build() => null;

  void set(String? activityId) => state = activityId;
}

/// The window the loaded months cover, oldest instant first.
@riverpod
DayWindow historyWindowStart(Ref ref) {
  final months = ref.watch(historyMonthsProvider);
  final calculator = ref.watch(dayWindowsProvider);
  final today = ref.watch(appClockProvider).nowUtc().toLocal();
  final first = DateTime(today.year, today.month - (months - 1));
  return calculator.forDate(first.year, first.month, first.day);
}

/// Every live entry in the loaded months, newest first.
@riverpod
Stream<List<TimeEntry>> historyEntries(Ref ref) {
  final from = ref.watch(historyWindowStartProvider).startUtc;
  final calculator = ref.watch(dayWindowsProvider);
  final to = calculator.containing(ref.watch(appClockProvider).nowUtc()).endUtc;
  return ref
      .watch(timeEntryRepositoryProvider)
      .watchEntriesInRange(from, to)
      .map((entries) => entries.reversed.toList());
}

/// The entries the list should show: loaded, then filtered, then searched.
///
/// Search covers the activity's name *and* the entry's note, because the note
/// is what distinguishes two spans of the same activity (SPEC §5.1) and is
/// therefore what you remember about one.
@riverpod
List<TimeEntry> visibleHistory(Ref ref) {
  final entries =
      ref.watch(historyEntriesProvider).value ?? const <TimeEntry>[];
  final activities =
      ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
  final filter = ref.watch(historyActivityFilterProvider);
  final query = ref.watch(historyQueryProvider).trim().toLowerCase();

  return entries.where((entry) {
    if (filter != null && entry.activityId != filter) return false;
    if (query.isEmpty) return true;
    final name = activities[entry.activityId]?.name.toLowerCase() ?? '';
    final note = entry.note?.toLowerCase() ?? '';
    return name.contains(query) || note.contains(query);
  }).toList();
}

/// The visible entries grouped into days, newest day first.
@riverpod
List<HistoryDay> historyDays(Ref ref) {
  final calculator = ref.watch(dayWindowsProvider);
  final grouped = <DayWindow, List<TimeEntry>>{};

  for (final entry in ref.watch(visibleHistoryProvider)) {
    // Grouped by the day an entry *started*: one entry, one row, even when it
    // crosses midnight. The calendar is where a crossing entry appears twice
    // (SPEC §5.3); a list of what you did wants one line per thing you did.
    final window = calculator.containing(entry.startUtc);
    (grouped[window] ??= <TimeEntry>[]).add(entry);
  }

  return <HistoryDay>[
    for (final day in grouped.keys)
      HistoryDay(window: day, entries: grouped[day]!),
  ];
}

/// One day's worth of history.
class HistoryDay {
  const HistoryDay({required this.window, required this.entries});

  final DayWindow window;
  final List<TimeEntry> entries;
}
