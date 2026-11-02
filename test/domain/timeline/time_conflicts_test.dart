import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/invariants.dart';
import 'package:time_log/src/domain/timeline/time_conflicts.dart';

/// SPEC §7.1, §7.2: typed input is reported, never silently moved, and says what
/// happens to the entries beside it.
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

  test('an overlap is not a conflict: it trims the neighbour', () {
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(9, 30),
        endUtc: at(11),
        previous: entry('p', at(8), at(10)),
        now: now,
      ),
      isNull,
    );
    expect(
      findTimeConflict(
        original: target,
        startUtc: at(9),
        endUtc: at(11, 30),
        next: entry('n', at(11), at(12)),
        now: now,
      ),
      isNull,
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

  group('typedTrimBelowTheMinimumIsRejectedWithNamedConflict', () {
    test('for the previous entry, shared or not', () {
      expect(
        findTimeConflict(
          original: target,
          startUtc: at(8).add(const Duration(seconds: 30)),
          endUtc: at(15),
          previous: entry('p', at(8), at(10)),
          now: now,
        ),
        isA<PreviousWouldBeTooShort>(),
      );
    });

    test('for the next entry, shared or not', () {
      expect(
        findTimeConflict(
          original: target,
          startUtc: at(14),
          endUtc: at(16, 30),
          next: entry('n', at(16), at(16, 30)),
          now: now,
        ),
        isA<NextWouldBeTooShort>(),
      );
    });

    test('a move past the neighbour entirely is the same refusal', () {
      expect(
        findTimeConflict(
          original: target,
          startUtc: at(7),
          endUtc: at(15),
          previous: entry('p', at(8), at(10)),
          now: now,
        ),
        isA<PreviousWouldBeTooShort>(),
      );
    });

    test('a running next entry has no far edge to protect', () {
      expect(
        findTimeConflict(
          original: target,
          startUtc: at(14),
          endUtc: at(16, 30),
          next: entry('n', at(16), null),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('resolveTimesEdit (SPEC §7.1)', () {
    final previous = entry('p', at(13), at(14));
    final next = entry('n', at(15), at(16));

    test('moving away from a touching neighbour reports it, unchanged', () {
      final edit = resolveTimesEdit(
        original: target,
        startUtc: at(14, 15),
        endUtc: at(14, 45),
        previous: previous,
        next: next,
      );

      expect(edit.previous, isNull);
      expect(edit.next, isNull);
      expect(edit.detachedPrevious, previous);
      expect(edit.detachedNext, next);
    });

    test('a carried neighbour moves and is no longer detached', () {
      final edit = resolveTimesEdit(
        original: target,
        startUtc: at(14, 15),
        endUtc: at(14, 45),
        previous: previous,
        next: next,
        carryPrevious: true,
        carryNext: true,
      );

      expect(edit.previous!.endUtc, at(14, 15));
      expect(edit.next!.startUtc, at(14, 45));
      expect(edit.detachedPrevious, isNull);
      expect(edit.detachedNext, isNull);
    });

    test('anOverlapTrimsTheNeighbourWithoutAsking', () {
      final edit = resolveTimesEdit(
        original: target,
        startUtc: at(13, 30),
        endUtc: at(15, 30),
        previous: previous,
        next: next,
      );

      expect(edit.previous!.endUtc, at(13, 30));
      expect(edit.next!.startUtc, at(15, 30));
      expect(edit.detachedPrevious, isNull);
      expect(edit.detachedNext, isNull);
    });

    test('an overlap across a gap trims too', () {
      final edit = resolveTimesEdit(
        original: target,
        startUtc: at(12, 30),
        endUtc: at(15),
        previous: entry('p', at(12), at(13)),
      );

      expect(edit.previous!.endUtc, at(12, 30));
    });

    test('a free edge inside its gap changes nothing and asks nothing', () {
      final edit = resolveTimesEdit(
        original: target,
        startUtc: at(13, 30),
        endUtc: at(15, 30),
        previous: entry('p', at(12), at(13)),
        next: entry('n', at(16), at(17)),
      );

      expect(edit.previous, isNull);
      expect(edit.next, isNull);
      expect(edit.detachedPrevious, isNull);
      expect(edit.detachedNext, isNull);
    });

    test('an edge that did not move leaves its neighbour alone', () {
      final edit = resolveTimesEdit(
        original: target,
        startUtc: at(14),
        endUtc: at(14, 30),
        previous: previous,
      );

      expect(edit.previous, isNull);
      expect(edit.detachedPrevious, isNull);
    });
  });
}
