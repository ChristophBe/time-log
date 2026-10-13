import '../models/time_entry.dart';
import 'day_window.dart';

/// How many midnights one rollover pass will backfill before it decides the
/// clock was forgotten rather than running (SPEC §6.11).
const int kMaxRolloverDays = 366;

/// What SPEC §6.11 has to do to the running entry: the midnights it has
/// crossed, oldest first.
class RolloverPlan {
  const RolloverPlan({required this.boundaries, required this.abandoned});

  const RolloverPlan.nothingToDo()
    : boundaries = const <DateTime>[],
      abandoned = false;

  /// The instants to cut at. Each one ends the entry before it and starts the
  /// one after it, so they are shared boundaries (SPEC §4.4).
  final List<DateTime> boundaries;

  /// The run crossed more than [kMaxRolloverDays] midnights, which is a
  /// forgotten clock and not a year of work: cut at the first boundary and do
  /// **not** restart, so the app comes back with nothing running rather than
  /// with hundreds of invented days.
  final bool abandoned;

  bool get isEmpty => boundaries.isEmpty;
}

/// Plans the cuts for a run that began at [startUtc] (SPEC §6.11).
///
/// The boundaries come from [days] rather than from `+ 24h` arithmetic, so a
/// DST day is 23 or 25 hours long and the cut lands on the midnight the user
/// actually lived through (SPEC §5.3).
///
/// Every boundary is `<= now`, because §4.5 forbids an end in the future: the
/// cut can only ever be made after the fact.
RolloverPlan planDayRollover({
  required DateTime startUtc,
  required DateTime now,
  required DayWindowCalculator days,
  int maxDays = kMaxRolloverDays,
}) {
  // A backwards clock jump is §9.2's problem, not this one.
  if (!now.isAfter(startUtc)) return const RolloverPlan.nothingToDo();

  final boundaries = <DateTime>[];
  var window = days.containing(startUtc);
  while (!window.endUtc.isAfter(now)) {
    boundaries.add(window.endUtc);
    if (boundaries.length > maxDays) {
      return RolloverPlan(
        boundaries: <DateTime>[boundaries.first],
        abandoned: true,
      );
    }
    window = days.next(window);
  }
  return RolloverPlan(boundaries: boundaries, abandoned: false);
}

/// Whether [entry] is the other half of [previous], cut apart by a rollover
/// (SPEC §6.11).
///
/// Used to measure a run across the cuts, so the long-run banner still asks
/// about a clock left on overnight (SPEC §8.1). The join has to *be* a local
/// midnight: §6.6 splitting and §6.10 relabelling can both leave two touching
/// entries sharing an activity, and neither of those is one run.
///
/// The note is deliberately not compared. A rollover copies it, but editing the
/// note afterwards should not make the app forget how long you have been at
/// this.
bool isRolloverContinuation({
  required TimeEntry entry,
  required TimeEntry previous,
  required DayWindowCalculator days,
}) {
  if (previous.activityId != entry.activityId) return false;
  final end = previous.endUtc;
  if (end == null || !end.isAtSameMomentAs(entry.startUtc)) return false;
  return days
      .containing(entry.startUtc)
      .startUtc
      .isAtSameMomentAs(entry.startUtc);
}
