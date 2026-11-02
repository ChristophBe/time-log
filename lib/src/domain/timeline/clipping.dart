import '../models/time_entry.dart';

/// The part of an entry that falls inside a window, or null if none of it does.
typedef ClippedSpan = ({DateTime start, DateTime end});

/// The slice of [entry] inside the half-open window `[from, to)`.
///
/// One piece of arithmetic with two callers — the day totals (SPEC §5.3) and
/// the CSV export (SPEC §8.6) — because a day's total and an export of that day
/// disagreeing about how much time was tracked would be worse than either being
/// wrong on its own.
///
/// A running entry is measured to [now], and then clipped like any other: a
/// window that ended yesterday does not keep growing.
ClippedSpan? clipToWindow(
  TimeEntry entry, {
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  return clipSpan(
    start: entry.startUtc,
    end: entry.endOr(now),
    from: from,
    to: to,
  );
}

/// The slice of `[start, end)` inside the half-open window `[from, to)`, or null
/// if none of it is. Active sessions (SPEC §9.9) clip by this arithmetic too.
ClippedSpan? clipSpan({
  required DateTime start,
  required DateTime end,
  required DateTime from,
  required DateTime to,
}) {
  final clippedStart = start.isBefore(from) ? from : start;
  final clippedEnd = end.isAfter(to) ? to : end;
  if (!clippedEnd.isAfter(clippedStart)) return null;
  return (start: clippedStart, end: clippedEnd);
}
