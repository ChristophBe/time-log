import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/invariants.dart';
import 'package:time_log/src/domain/timeline/time_conflicts.dart';

/// SPEC §7.2: typed input is reported, never silently moved.
void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 3, 10, hour, minute);
  final now = at(18);

  TimeEntry entry(String id, DateTime start, DateTime? end) => TimeEntry(
    id: id,
    activityId: 'a',
    startUtc: start,
    endUtc: end,
    tzName: 'UTC',
  );

  /// The entry being edited, at times that touch nothing, so each test opts in
  /// to sharing explicitly.
  final target = entry('target', at(14), at(15));

  test('a clean pair has no conflict', () {
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(9),
        endUtc: at(10),
        now: now,
      ),
      isNull,
    );
  });

  test('an end at or before the start is rejected', () {
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(10),
        endUtc: at(9),
        now: now,
      ),
      isA<EndNotAfterStart>(),
    );
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(10),
        endUtc: at(10),
        now: now,
      ),
      isA<EndNotAfterStart>(),
    );
  });

  test('shorter than the minimum is rejected with the minimum reported', () {
    final conflict = findTimeConflict(
      original: target,
      startUtc: at(10),
      endUtc: at(10, 0).add(const Duration(seconds: 30)),
      now: now,
    );
    expect(conflict, isA<ShorterThanMinimum>());
    expect((conflict! as ShorterThanMinimum).minimum, kMinEntryLength);
  });

  test('future times are rejected', () {
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(19),
        endUtc: at(20),
        now: now,
      ),
      isA<InTheFuture>(),
    );
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(17),
        endUtc: at(20),
        now: now,
      ),
      isA<InTheFuture>(),
    );
  });

  test('typedOverlapIsRejectedWithNamedConflict for the previous entry', () {
    final conflict = findTimeConflict(
      original: target,
      startUtc: at(9, 30),
      endUtc: at(11),
      previous: entry('p', at(8), at(10)),
      now: now,
    );
    expect(conflict, isA<OverlapsPrevious>());
    expect(
      (conflict! as OverlapsPrevious).untilUtc,
      at(10),
      reason: 'the message can name when the neighbour actually ends',
    );
  });

  test('touching the previous entry exactly is fine', () {
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(10),
        endUtc: at(11),
        previous: entry('p', at(8), at(10)),
        now: now,
      ),
      isNull,
    );
  });

  test('overlapping the next entry is rejected', () {
    final conflict = findTimeConflict(
      original: target,
      startUtc: at(9),
      endUtc: at(11, 30),
      next: entry('n', at(11), at(12)),
      now: now,
    );
    expect(conflict, isA<OverlapsNext>());
    expect((conflict! as OverlapsNext).fromUtc, at(11));
  });

  test('a running entry measured to now may not reach the next entry', () {
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(9),
        next: entry('n', at(12), at(13)),
        now: now,
      ),
      isA<OverlapsNext>(),
      reason: 'a running entry reaches now, which is past 12:00',
    );
  });

  test('a running previous entry blocks anything after its start', () {
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(10),
        endUtc: at(11),
        previous: entry('p', at(9), null),
        now: now,
      ),
      isA<OverlapsPrevious>(),
    );
  });
}
