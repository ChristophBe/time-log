import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_timeline.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';

void main() {
  final window = DayWindow(
    startUtc: DateTime.utc(2026, 3, 10),
    endUtc: DateTime.utc(2026, 3, 11),
    year: 2026,
    month: 3,
    day: 10,
  );
  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 3, 10, hour, minute);

  TimeEntry entry(String id, DateTime start, DateTime? end) => TimeEntry(
    id: id,
    activityId: 'a',
    startUtc: start,
    endUtc: end,
    tzName: 'UTC',
  );

  test('segments keep their order and times', () {
    final timeline = buildDayTimeline(
      window: window,
      entries: <TimeEntry>[
        entry('2', at(13), at(14)),
        entry('1', at(9), at(10)),
      ],
      now: at(15),
    );
    expect(timeline.segments.map((s) => s.entry.id), <String>['1', '2']);
    expect(timeline.segments.first.startUtc, at(9));
    expect(timeline.segments.first.visibleDuration, const Duration(hours: 1));
  });

  test('entryCrossingMidnightRendersInBothDays', () {
    final crossing = entry(
      'night',
      DateTime.utc(2026, 3, 9, 23),
      DateTime.utc(2026, 3, 10, 1),
    );
    final previousDay = DayWindow(
      startUtc: DateTime.utc(2026, 3, 9),
      endUtc: DateTime.utc(2026, 3, 10),
      year: 2026,
      month: 3,
      day: 9,
    );

    final first = buildDayTimeline(
      window: previousDay,
      entries: <TimeEntry>[crossing],
      now: at(15),
    );
    final second = buildDayTimeline(
      window: window,
      entries: <TimeEntry>[crossing],
      now: at(15),
    );

    expect(first.segments.single.endUtc, DateTime.utc(2026, 3, 10));
    expect(first.segments.single.continuesAfter, isTrue);
    expect(first.segments.single.continuesBefore, isFalse);

    expect(second.segments.single.startUtc, DateTime.utc(2026, 3, 10));
    expect(second.segments.single.continuesBefore, isTrue);
    expect(second.segments.single.continuesAfter, isFalse);

    expect(
      second.segments.single.fullDuration(at(15)),
      const Duration(hours: 2),
      reason: 'the label states the whole span, not just the visible slice',
    );
  });

  test('entries outside the day are dropped', () {
    final timeline = buildDayTimeline(
      window: window,
      entries: <TimeEntry>[
        entry('before', DateTime.utc(2026, 3, 8), DateTime.utc(2026, 3, 9)),
        entry('after', DateTime.utc(2026, 3, 12), DateTime.utc(2026, 3, 13)),
      ],
      now: DateTime.utc(2026, 3, 14),
    );
    expect(timeline.segments, isEmpty);
  });

  test('a running entry is clipped to now', () {
    final timeline = buildDayTimeline(
      window: window,
      entries: <TimeEntry>[entry('r', at(9), null)],
      now: at(11, 30),
    );
    expect(timeline.segments.single.endUtc, at(11, 30));
    expect(timeline.segments.single.isRunning, isTrue);
  });

  group('gaps', () {
    test('a gap between two entries is reported', () {
      final timeline = buildDayTimeline(
        window: window,
        entries: <TimeEntry>[
          entry('1', at(9), at(10)),
          entry('2', at(11), at(12)),
        ],
        now: at(12),
      );
      final between = timeline.gaps.where((g) => g.startUtc == at(10));
      expect(between, hasLength(1));
      expect(between.single.duration, const Duration(hours: 1));
    });

    test('touching entries produce no gap', () {
      final timeline = buildDayTimeline(
        window: window,
        entries: <TimeEntry>[
          entry('1', at(9), at(10)),
          entry('2', at(10), at(11)),
        ],
        now: at(11),
      );
      expect(timeline.gaps.any((g) => g.startUtc == at(10)), isFalse);
    });

    test('a gap under five minutes is not drawn', () {
      final timeline = buildDayTimeline(
        window: window,
        entries: <TimeEntry>[
          entry('1', at(9), at(10)),
          entry('2', at(10, 2), at(11)),
        ],
        now: at(11),
      );
      expect(timeline.gaps.any((g) => g.startUtc == at(10)), isFalse);
    });

    test('gaps stop at now, so the future is not called untracked', () {
      final timeline = buildDayTimeline(
        window: window,
        entries: <TimeEntry>[entry('1', at(9), at(10))],
        now: at(11),
      );
      expect(timeline.gaps.last.endUtc, at(11));
    });

    test('a past day has gaps up to midnight', () {
      final timeline = buildDayTimeline(
        window: window,
        entries: <TimeEntry>[entry('1', at(9), at(10))],
        now: DateTime.utc(2026, 3, 12),
      );
      expect(timeline.gaps.last.endUtc, window.endUtc);
    });

    test('a day with no entries is one gap up to now', () {
      final timeline = buildDayTimeline(
        window: window,
        entries: const <TimeEntry>[],
        now: at(8),
      );
      expect(timeline.isEmpty, isTrue);
      expect(timeline.gaps.single.startUtc, window.startUtc);
      expect(timeline.gaps.single.endUtc, at(8));
    });

    test('nothing is drawn for a day that has not started', () {
      final timeline = buildDayTimeline(
        window: window,
        entries: const <TimeEntry>[],
        now: DateTime.utc(2026, 3, 9, 12),
      );
      expect(timeline.gaps, isEmpty);
    });
  });
}
