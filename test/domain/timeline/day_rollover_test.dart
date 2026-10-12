import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_rollover.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';

/// SPEC §6.11. The days are hand-built and contiguous, so a 23-hour day can be
/// handed to the planner without depending on the test host's time zone.
void main() {
  DayWindowCalculator calendar(List<Duration> lengths) {
    final windows = <DayWindow>[];
    var start = DateTime.utc(2026, 3, 9);
    for (var i = 0; i < lengths.length; i++) {
      windows.add(
        DayWindow(
          startUtc: start,
          endUtc: start.add(lengths[i]),
          year: 2026,
          month: 3,
          day: 9 + i,
        ),
      );
      start = start.add(lengths[i]);
    }
    return FixedDayWindowCalculator(windows);
  }

  DayWindowCalculator days(int count) =>
      calendar(List<Duration>.filled(count, const Duration(hours: 24)));

  TimeEntry entry({
    required String id,
    required String activityId,
    required DateTime start,
    DateTime? end,
  }) => TimeEntry(
    id: id,
    activityId: activityId,
    startUtc: start,
    endUtc: end,
    tzName: 'UTC',
  );

  group('planDayRollover', () {
    test('runningEntryIsCutAtMidnight', () {
      final plan = planDayRollover(
        startUtc: DateTime.utc(2026, 3, 9, 22),
        now: DateTime.utc(2026, 3, 10, 6),
        days: days(3),
      );
      expect(plan.boundaries, <DateTime>[DateTime.utc(2026, 3, 10)]);
      expect(plan.abandoned, isFalse);
    });

    test('a run inside one day is not cut', () {
      final plan = planDayRollover(
        startUtc: DateTime.utc(2026, 3, 9, 9),
        now: DateTime.utc(2026, 3, 9, 17),
        days: days(3),
      );
      expect(plan.isEmpty, isTrue);
    });

    test('rollOverBackfillsEveryMissedMidnight', () {
      final plan = planDayRollover(
        startUtc: DateTime.utc(2026, 3, 9, 22),
        now: DateTime.utc(2026, 3, 12, 9),
        days: days(5),
      );
      expect(plan.boundaries, <DateTime>[
        DateTime.utc(2026, 3, 10),
        DateTime.utc(2026, 3, 11),
        DateTime.utc(2026, 3, 12),
      ]);
    });

    test('a boundary exactly at now is still cut', () {
      final plan = planDayRollover(
        startUtc: DateTime.utc(2026, 3, 9, 22),
        now: DateTime.utc(2026, 3, 10),
        days: days(3),
      );
      expect(plan.boundaries, <DateTime>[
        DateTime.utc(2026, 3, 10),
      ], reason: 'the cut is legal the instant it stops being in the future');
    });

    test('rollOverFollowsDstDayLength', () {
      final plan = planDayRollover(
        startUtc: DateTime.utc(2026, 3, 9, 22),
        now: DateTime.utc(2026, 3, 10, 6),
        // A 23-hour day: midnight arrives an hour early in UTC terms.
        days: calendar(<Duration>[
          const Duration(hours: 23),
          const Duration(hours: 24),
          const Duration(hours: 24),
        ]),
      );
      expect(plan.boundaries, <DateTime>[
        DateTime.utc(2026, 3, 9, 23),
      ], reason: 'SPEC §5.3: the cut lands on the real boundary, not on +24h');
    });

    test('a backwards clock plans nothing', () {
      final plan = planDayRollover(
        startUtc: DateTime.utc(2026, 3, 10, 9),
        now: DateTime.utc(2026, 3, 10, 8),
        days: days(3),
      );
      expect(
        plan.isEmpty,
        isTrue,
        reason: 'SPEC §9.2 owns the backwards-clock case, not §6.11',
      );
    });

    test('a run past the cap is cut once and abandoned', () {
      final plan = planDayRollover(
        startUtc: DateTime.utc(2026, 3, 9, 22),
        now: DateTime.utc(2026, 3, 13, 9),
        days: days(6),
        maxDays: 2,
      );
      expect(plan.abandoned, isTrue);
      expect(plan.boundaries, <DateTime>[
        DateTime.utc(2026, 3, 10),
      ], reason: 'closed at the first midnight and not picked back up');
    });
  });

  group('isRolloverContinuation', () {
    final earlier = entry(
      id: 'a',
      activityId: 'specs',
      start: DateTime.utc(2026, 3, 9, 22),
      end: DateTime.utc(2026, 3, 10),
    );
    final later = entry(
      id: 'b',
      activityId: 'specs',
      start: DateTime.utc(2026, 3, 10),
    );

    test('two halves of a cut run are one run', () {
      expect(
        isRolloverContinuation(entry: later, previous: earlier, days: days(3)),
        isTrue,
      );
    });

    test('a different activity is a different run', () {
      expect(
        isRolloverContinuation(
          entry: later,
          previous: entry(
            id: 'a',
            activityId: 'email',
            start: DateTime.utc(2026, 3, 9, 22),
            end: DateTime.utc(2026, 3, 10),
          ),
          days: days(3),
        ),
        isFalse,
      );
    });

    test('a gap between them is a different run', () {
      expect(
        isRolloverContinuation(
          entry: later,
          previous: entry(
            id: 'a',
            activityId: 'specs',
            start: DateTime.utc(2026, 3, 9, 22),
            end: DateTime.utc(2026, 3, 9, 23),
          ),
          days: days(3),
        ),
        isFalse,
      );
    });

    test('a join that is not a midnight is not a rollover', () {
      // What §6.6 splitting and §6.10 relabelling leave behind: two touching
      // entries sharing an activity, in the middle of a day.
      expect(
        isRolloverContinuation(
          entry: entry(
            id: 'b',
            activityId: 'specs',
            start: DateTime.utc(2026, 3, 10, 14),
          ),
          previous: entry(
            id: 'a',
            activityId: 'specs',
            start: DateTime.utc(2026, 3, 10, 9),
            end: DateTime.utc(2026, 3, 10, 14),
          ),
          days: days(3),
        ),
        isFalse,
      );
    });
  });
}
