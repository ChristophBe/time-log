import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/invariants.dart';
import 'package:time_log/src/domain/timeline/timeline_math.dart';

/// SPEC §7, the boundary-editing rules. Pure functions, so these run without a
/// database or a widget tree.
void main() {
  final day = DateTime.utc(2026, 3, 10);
  DateTime at(int hour, [int minute = 0]) =>
      day.add(Duration(hours: hour, minutes: minute));
  final now = at(18);

  TimeEntry entry(
    String id,
    int fromHour,
    int? toHour, {
    int fromMin = 0,
    int? toMin,
  }) => TimeEntry(
    id: id,
    activityId: 'a-$id',
    startUtc: at(fromHour, fromMin),
    endUtc: toHour == null ? null : at(toHour, toMin ?? 0),
    tzName: 'UTC',
  );

  group('snapping', () {
    test('snapRoundsInstantNotDelta', () {
      final snapped = snapInstant(at(9, 7), const Duration(minutes: 5));
      expect(snapped, at(9, 5));
      expect(snapInstant(at(9, 8), const Duration(minutes: 5)), at(9, 10));
    });

    test('repeatedEditsDoNotDrift', () {
      // An off-grid instant lands on the grid and then stays there, however many
      // times it is nudged -- the point of snapping instants rather than deltas.
      var instant = at(9, 7);
      for (var i = 0; i < 10; i++) {
        instant = snapInstant(
          instant.add(const Duration(minutes: 5)),
          const Duration(minutes: 5),
        );
      }
      expect(instant.minute.remainder(5), 0);
      expect(
        instant,
        at(9, 55),
        reason:
            '9:07 snaps onto the grid once, then '
            'advances by exactly 5 minutes with no accumulated offset',
      );
    });

    test('a zero snap leaves the instant alone', () {
      expect(snapInstant(at(9, 7), Duration.zero), at(9, 7));
    });
  });

  group('shared boundaries (SPEC §7.1)', () {
    test('draggingSharedBoundaryConservesTotalTrackedTime', () {
      final a = entry('a', 9, 10);
      final b = entry('b', 10, 11);
      final totalBefore = const Duration(hours: 2);

      final move = resolveBoundaryMove(
        target: b,
        edge: BoundaryEdge.start,
        desired: at(10, 30),
        prev: a,
        snap: const Duration(minutes: 5),
        now: now,
      );

      expect(move.neighbour, isNotNull, reason: 'the neighbour moved too');
      final newA = move.neighbour!;
      final newB = move.target;
      expect(newA.endUtc, at(10, 30));
      expect(newB.startUtc, at(10, 30));
      expect(
        newA.durationAt(now) + newB.durationAt(now),
        totalBefore,
        reason: 'SPEC §7.1: a shared boundary conserves total tracked time',
      );
    });

    test('dragging a shared end moves the following entry start', () {
      final a = entry('a', 9, 10);
      final b = entry('b', 10, 11);

      final move = resolveBoundaryMove(
        target: a,
        edge: BoundaryEdge.end,
        desired: at(9, 30),
        next: b,
        snap: const Duration(minutes: 5),
        now: now,
      );

      expect(move.target.endUtc, at(9, 30));
      expect(move.neighbour!.startUtc, at(9, 30));
    });

    test('clampStopsAtNeighbourMinusMinimum', () {
      final a = entry('a', 9, 10);
      final b = entry('b', 10, 11);

      // Try to drag the shared boundary past the far end of b.
      final move = resolveBoundaryMove(
        target: b,
        edge: BoundaryEdge.start,
        desired: at(12),
        prev: a,
        snap: const Duration(minutes: 5),
        now: now,
      );

      expect(move.wasClamped, isTrue);
      expect(
        move.applied,
        at(11).subtract(kMinEntryLength),
        reason: 'b keeps its one-minute minimum',
      );
    });

    test('clamping also protects the shared neighbour minimum', () {
      final a = entry('a', 9, 10);
      final b = entry('b', 10, 11);

      final move = resolveBoundaryMove(
        target: b,
        edge: BoundaryEdge.start,
        desired: at(8),
        prev: a,
        snap: const Duration(minutes: 5),
        now: now,
      );

      expect(move.wasClamped, isTrue);
      expect(move.applied, at(9).add(kMinEntryLength));
    });
  });

  group('free boundaries (SPEC §7.1)', () {
    test('draggingFreeEdgeGrowsIntoGapOnly', () {
      final a = entry('a', 9, 10);
      final b = entry('b', 11, 12); // one-hour gap between a and b

      final move = resolveBoundaryMove(
        target: b,
        edge: BoundaryEdge.start,
        desired: at(10, 30),
        prev: a,
        snap: const Duration(minutes: 5),
        now: now,
      );

      expect(move.neighbour, isNull, reason: 'a is untouched across a gap');
      expect(move.target.startUtc, at(10, 30));
      expect(move.wasClamped, isFalse);
    });

    test('a free edge stops at the neighbour rather than overlapping it', () {
      final a = entry('a', 9, 10);
      final b = entry('b', 11, 12);

      final move = resolveBoundaryMove(
        target: b,
        edge: BoundaryEdge.start,
        desired: at(9, 30),
        prev: a,
        snap: const Duration(minutes: 5),
        now: now,
      );

      expect(move.wasClamped, isTrue);
      expect(
        move.applied,
        at(10),
        reason: 'it meets a exactly, never overlaps',
      );
    });

    test('a free end never lands in the future', () {
      final a = entry('a', 17, 18);

      final move = resolveBoundaryMove(
        target: a,
        edge: BoundaryEdge.end,
        desired: at(20),
        snap: const Duration(minutes: 5),
        now: now,
      );

      expect(move.applied, now);
      expect(move.wasClamped, isTrue);
    });
  });

  group('the running entry (SPEC §7.4)', () {
    test('runningEntryEndIsNotEditable', () {
      final running = entry('r', 17, null);
      expect(
        () => resolveBoundaryMove(
          target: running,
          edge: BoundaryEdge.end,
          desired: at(17, 30),
          snap: const Duration(minutes: 5),
          now: now,
        ),
        throwsA(isA<InvariantViolation>()),
      );
    });

    test('the running start can move, clamped to now minus the minimum', () {
      final running = entry('r', 17, null);
      final move = resolveBoundaryMove(
        target: running,
        edge: BoundaryEdge.start,
        desired: at(19),
        snap: const Duration(minutes: 5),
        now: now,
      );
      expect(move.applied, now);
      expect(move.target.isRunning, isTrue);
    });

    test('moving the running start earlier into a gap works', () {
      final running = entry('r', 17, null);
      final before = entry('a', 15, 16);
      final move = resolveBoundaryMove(
        target: running,
        edge: BoundaryEdge.start,
        desired: at(16, 30),
        prev: before,
        snap: const Duration(minutes: 5),
        now: now,
      );
      expect(move.neighbour, isNull);
      expect(move.target.startUtc, at(16, 30));
    });
  });

  test('changedEntries lists only what actually moved', () {
    final a = entry('a', 9, 10);
    final b = entry('b', 10, 11);
    final shared = resolveBoundaryMove(
      target: b,
      edge: BoundaryEdge.start,
      desired: at(10, 15),
      prev: a,
      snap: const Duration(minutes: 5),
      now: now,
    );
    expect(shared.changedEntries, hasLength(2));

    final free = resolveBoundaryMove(
      target: b,
      edge: BoundaryEdge.start,
      desired: at(10, 15),
      snap: const Duration(minutes: 5),
      now: now,
    );
    expect(free.changedEntries, hasLength(1));
  });
}
