import '../models/time_entry.dart';
import 'day_window.dart';

/// Per-day tracked and untracked totals (SPEC §8.1).
class DayTotals {
  const DayTotals({
    required this.tracked,
    required this.untracked,
    required this.byActivityId,
  });

  final Duration tracked;
  final Duration untracked;

  /// Tracked time per activity, inside this day only.
  final Map<String, Duration> byActivityId;

  /// Activity ids ordered by time spent, longest first.
  List<String> get rankedActivityIds {
    final ids = byActivityId.keys.toList()
      ..sort((a, b) => byActivityId[b]!.compareTo(byActivityId[a]!));
    return ids;
  }
}

/// Sums the parts of [entries] that fall inside [window].
///
/// An entry crossing midnight contributes only its slice of this day (SPEC
/// §5.3), and a running entry is measured to [now] -- but never past the end of
/// the window, so yesterday's totals do not keep growing.
DayTotals computeDayTotals({
  required Iterable<TimeEntry> entries,
  required DayWindow window,
  required DateTime now,
}) {
  var tracked = Duration.zero;
  final byActivity = <String, Duration>{};

  for (final entry in entries) {
    final start = entry.startUtc.isBefore(window.startUtc)
        ? window.startUtc
        : entry.startUtc;
    var end = entry.endOr(now);
    if (end.isAfter(window.endUtc)) end = window.endUtc;
    if (!end.isAfter(start)) continue;

    final slice = end.difference(start);
    tracked += slice;
    byActivity[entry.activityId] =
        (byActivity[entry.activityId] ?? Duration.zero) + slice;
  }

  // Untracked time is only meaningful up to now for today, and across the whole
  // window for a past day.
  final elapsedInWindow = now.isBefore(window.endUtc)
      ? (now.isAfter(window.startUtc)
            ? now.difference(window.startUtc)
            : Duration.zero)
      : window.length;
  final untracked = elapsedInWindow - tracked;

  return DayTotals(
    tracked: tracked,
    untracked: untracked.isNegative ? Duration.zero : untracked,
    byActivityId: byActivity,
  );
}
