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
  final start = entry.startUtc.isBefore(from) ? from : entry.startUtc;
  var end = entry.endOr(now);
  if (end.isAfter(to)) end = to;
  if (!end.isAfter(start)) return null;
  return (start: start, end: end);
}
