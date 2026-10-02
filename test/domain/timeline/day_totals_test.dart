import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_totals.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';

void main() {
  // A plain 24-hour UTC day, so the arithmetic is easy to read.
  final window = DayWindow(
    startUtc: DateTime.utc(2026, 3, 10),
    endUtc: DateTime.utc(2026, 3, 11),
    year: 2026,
    month: 3,
    day: 10,
  );

  TimeEntry entry(
    String id,
    DateTime start,
    DateTime? end, {
    String activity = 'a',
  }) => TimeEntry(
    id: id,
    activityId: activity,
    startUtc: start,
    endUtc: end,
    tzName: 'UTC',
  );

  test('sums entries inside the day', () {
    final totals = computeDayTotals(
      entries: <TimeEntry>[
        entry('1', DateTime.utc(2026, 3, 10, 9), DateTime.utc(2026, 3, 10, 11)),
        entry(
          '2',
          DateTime.utc(2026, 3, 10, 13),
          DateTime.utc(2026, 3, 10, 14),
        ),
      ],
      window: window,
      now: DateTime.utc(2026, 3, 10, 15),
    );
    expect(totals.tracked, const Duration(hours: 3));
  });

  test('dayTotalsClipToDayWindow for an entry crossing midnight', () {
    final totals = computeDayTotals(
      entries: <TimeEntry>[
        // 23:00 the previous day to 01:00 this day: only one hour belongs here.
        entry('1', DateTime.utc(2026, 3, 9, 23), DateTime.utc(2026, 3, 10, 1)),
        // 23:30 today to 00:30 tomorrow: 30 minutes belong here.
        entry(
          '2',
          DateTime.utc(2026, 3, 10, 23, 30),
          DateTime.utc(2026, 3, 11, 0, 30),
        ),
      ],
      window: window,
      now: DateTime.utc(2026, 3, 11, 1),
    );
    expect(totals.tracked, const Duration(hours: 1, minutes: 30));
  });

  test('a running entry is measured to now, not past it', () {
    final totals = computeDayTotals(
      entries: <TimeEntry>[entry('1', DateTime.utc(2026, 3, 10, 9), null)],
      window: window,
      now: DateTime.utc(2026, 3, 10, 10, 30),
    );
    expect(totals.tracked, const Duration(hours: 1, minutes: 30));
  });

  test("a past day's running entry does not keep growing", () {
    final totals = computeDayTotals(
      entries: <TimeEntry>[entry('1', DateTime.utc(2026, 3, 10, 22), null)],
      window: window,
      // Days later: the slice must stop at midnight.
      now: DateTime.utc(2026, 3, 14),
    );
    expect(totals.tracked, const Duration(hours: 2));
  });

  test('untracked time is measured to now on the current day', () {
    final totals = computeDayTotals(
      entries: <TimeEntry>[
        entry('1', DateTime.utc(2026, 3, 10, 9), DateTime.utc(2026, 3, 10, 10)),
      ],
      window: window,
      now: DateTime.utc(2026, 3, 10, 12),
    );
    // Midnight to noon is 12 hours, one of them tracked.
    expect(totals.untracked, const Duration(hours: 11));
  });

  test('untracked time spans the whole window for a past day', () {
    final totals = computeDayTotals(
      entries: <TimeEntry>[
        entry('1', DateTime.utc(2026, 3, 10, 9), DateTime.utc(2026, 3, 10, 10)),
      ],
      window: window,
      now: DateTime.utc(2026, 3, 12),
    );
    expect(totals.untracked, const Duration(hours: 23));
  });

  test('totals are grouped and ranked per activity', () {
    final totals = computeDayTotals(
      entries: <TimeEntry>[
        entry(
          '1',
          DateTime.utc(2026, 3, 10, 9),
          DateTime.utc(2026, 3, 10, 10),
          activity: 'email',
        ),
        entry(
          '2',
          DateTime.utc(2026, 3, 10, 10),
          DateTime.utc(2026, 3, 10, 13),
          activity: 'specs',
        ),
        entry(
          '3',
          DateTime.utc(2026, 3, 10, 13),
          DateTime.utc(2026, 3, 10, 14),
          activity: 'email',
        ),
      ],
      window: window,
      now: DateTime.utc(2026, 3, 10, 15),
    );
    expect(totals.byActivityId['email'], const Duration(hours: 2));
    expect(totals.byActivityId['specs'], const Duration(hours: 3));
    expect(totals.rankedActivityIds, <String>['specs', 'email']);
  });

  test('untracked is never negative', () {
    final totals = computeDayTotals(
      entries: <TimeEntry>[
        entry('1', DateTime.utc(2026, 3, 10), DateTime.utc(2026, 3, 10, 12)),
      ],
      window: window,
      now: DateTime.utc(2026, 3, 10, 6),
    );
    expect(totals.untracked, Duration.zero);
  });
}
