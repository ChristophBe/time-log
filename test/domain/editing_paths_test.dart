import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/invariants.dart';
import 'package:time_log/src/domain/timeline/timeline_math.dart';

import '../support/fixtures.dart';

/// SPEC §14.5: the same correction made by drag, by typing and by keyboard must
/// produce the same timeline.
///
/// Each path is exercised through the writer exactly as the UI calls it:
///   - drag      -> moveBoundary with the instant under the finger
///   - keyboard  -> moveBoundary with the current boundary plus one snap step
///   - steppers  -> the same call as keyboard (the entry sheet's +/- buttons)
///   - typing    -> setEntryTimes with an exact instant, unsnapped
void main() {
  const snap = Duration(minutes: 5);
  final target = DateTime.utc(2026, 3, 10, 10, 30);

  /// A day with two touching entries, A 09:00-10:00 and B 10:00-11:00, with
  /// `now` at 12:00.
  Future<({TimelineHarness h, TimeEntry a, TimeEntry b})> twoTouching() async {
    final h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9));
    await h.writer.startByName(name: 'A');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.startByName(name: 'B');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.stop();
    h.clock.advance(const Duration(hours: 1));
    final entries = await h.entries();
    return (h: h, a: entries[0], b: entries[1]);
  }

  /// A day whose second entry is still **running**: A 09:00-10:00 and
  /// B 10:00-running, with `now` at 12:00.
  Future<({TimelineHarness h, TimeEntry a, TimeEntry b})>
  oneFinishedThenRunning() async {
    final h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9));
    await h.writer.startByName(name: 'A');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.startByName(name: 'B');
    h.clock.advance(const Duration(hours: 2));
    final entries = await h.entries();
    return (h: h, a: entries[0], b: entries[1]);
  }

  String shape(List<TimeEntry> entries) =>
      entries.map((e) => '${e.startUtc}-${e.endUtc}').join(' | ');

  test('drag, keyboard and typing move a shared boundary identically', () async {
    final results = <String>[];

    // Path 1: drag. The finger lands off-grid at 10:31; snapping takes the
    // boundary to 10:30 (SPEC §7.3).
    {
      final setup = await twoTouching();
      await setup.h.writer.moveBoundary(
        entryId: setup.b.id,
        edge: BoundaryEdge.start,
        desired: DateTime.utc(2026, 3, 10, 10, 31),
        snap: snap,
        carryNeighbour: true,
      );
      results.add(shape(await setup.h.entries()));
      await setup.h.close();
    }

    // Path 2: keyboard and the entry sheet's steppers -- six nudges of one snap.
    {
      final setup = await twoTouching();
      var start = setup.b.startUtc;
      for (var i = 0; i < 6; i++) {
        start = start.add(snap);
        await setup.h.writer.moveBoundary(
          entryId: setup.b.id,
          edge: BoundaryEdge.start,
          desired: start,
          snap: snap,
          carryNeighbour: true,
        );
      }
      results.add(shape(await setup.h.entries()));
      await setup.h.close();
    }

    // Path 3: typing the exact time. Typed input is not snapped, and answering
    // Adjust lands both sides on the typed instant.
    {
      final setup = await twoTouching();
      await setup.h.writer.setEntryTimes(
        entryId: setup.b.id,
        startUtc: target,
        endUtc: setup.b.endUtc,
        carryPrevious: true,
      );
      results.add(shape(await setup.h.entries()));
      await setup.h.close();
    }

    expect(
      results.toSet(),
      hasLength(1),
      reason: 'SPEC §14.5: all three paths must agree. Got: $results',
    );
    expect(results.first, contains('$target'));
  });

  test(
    'a shared-boundary drag conserves total tracked time end to end',
    () async {
      final setup = await twoTouching();
      final before = await setup.h.totalTracked();

      await setup.h.writer.moveBoundary(
        entryId: setup.b.id,
        edge: BoundaryEdge.start,
        desired: target,
        snap: snap,
        carryNeighbour: true,
      );

      expect(await setup.h.totalTracked(), before, reason: 'SPEC §7.1');
      await setup.h.close();
    },
  );

  test('a free edge grows into a gap and leaves the neighbour alone', () async {
    final h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9));
    final first = await h.writer.startByName(name: 'A');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.stop();
    // An hour of untracked time, then B.
    h.clock.advance(const Duration(hours: 1));
    final second = await h.writer.startByName(name: 'B');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.stop();

    final aEndBefore = (await h.byId(first.entryId)).endUtc;
    await h.writer.moveBoundary(
      entryId: second.entryId,
      edge: BoundaryEdge.start,
      desired: target,
      snap: snap,
    );

    expect((await h.byId(first.entryId)).endUtc, aEndBefore);
    expect((await h.byId(second.entryId)).startUtc, target);
    await h.close();
  });

  test('a clamped drag reports it and still leaves a valid timeline', () async {
    final setup = await twoTouching();
    final outcome = await setup.h.writer.moveBoundary(
      entryId: setup.b.id,
      edge: BoundaryEdge.start,
      // Far past the far end of B.
      desired: DateTime.utc(2026, 3, 10, 23),
      snap: snap,
      carryNeighbour: true,
    );

    expect(outcome.wasClamped, isTrue);
    final entries = await setup.h.entries();
    expect(entries[1].endUtc!.isAfter(entries[1].startUtc), isTrue);
    expect(entries[0].endUtc, entries[1].startUtc);
    await setup.h.close();
  });

  test(
    'undo of a shared-boundary move restores both entries in one step',
    () async {
      final setup = await twoTouching();
      final before = shape(await setup.h.entries());

      final outcome = await setup.h.writer.moveBoundary(
        entryId: setup.b.id,
        edge: BoundaryEdge.start,
        desired: target,
        snap: snap,
        carryNeighbour: true,
      );
      await outcome.undo.undo();

      expect(
        shape(await setup.h.entries()),
        before,
        reason: 'SPEC §7.5: one undo step covers every edge the drag moved',
      );
      await setup.h.close();
    },
  );

  test(
    'typing a shared boundary away carries the neighbour on request',
    () async {
      final setup = await twoTouching();

      await setup.h.writer.setEntryTimes(
        entryId: setup.b.id,
        startUtc: target,
        endUtc: setup.b.endUtc,
        carryPrevious: true,
      );

      final entries = await setup.h.entries();
      expect(entries[0].endUtc, target);
      expect(entries[1].startUtc, target);
      await setup.h.close();
    },
  );

  test('Leave gap moves only this entry, on every path', () async {
    final results = <String>[];

    {
      final setup = await twoTouching();
      final preview = await setup.h.writer.previewBoundaryMove(
        entryId: setup.b.id,
        edge: BoundaryEdge.start,
        desired: target,
        snap: snap,
      );
      expect(preview.detachedNeighbour?.id, setup.a.id);
      await setup.h.writer.moveBoundary(
        entryId: setup.b.id,
        edge: BoundaryEdge.start,
        desired: target,
        snap: snap,
      );
      results.add(shape(await setup.h.entries()));
      await setup.h.close();
    }

    {
      final setup = await twoTouching();
      await setup.h.writer.setEntryTimes(
        entryId: setup.b.id,
        startUtc: target,
        endUtc: setup.b.endUtc,
      );
      final entries = await setup.h.entries();
      expect(
        entries[0].endUtc,
        setup.a.endUtc,
        reason: 'A was not asked to move',
      );
      results.add(shape(entries));
      await setup.h.close();
    }

    expect(results.toSet(), hasLength(1), reason: 'SPEC §14.5');
  });

  test('previewing a move writes nothing', () async {
    final setup = await twoTouching();
    final before = shape(await setup.h.entries());

    await setup.h.writer.previewBoundaryMove(
      entryId: setup.b.id,
      edge: BoundaryEdge.start,
      desired: target,
      snap: snap,
    );

    expect(shape(await setup.h.entries()), before);
    await setup.h.close();
  });

  test('typing into a neighbour trims it without being asked to', () async {
    final setup = await twoTouching();

    await setup.h.writer.setEntryTimes(
      entryId: setup.b.id,
      startUtc: DateTime.utc(2026, 3, 10, 9, 30),
      endUtc: setup.b.endUtc,
    );

    final entries = await setup.h.entries();
    expect(
      entries[0].endUtc,
      DateTime.utc(2026, 3, 10, 9, 30),
      reason: 'SPEC §7.1 applies to typed input too, not only to drags',
    );
    expect(entries[1].startUtc, DateTime.utc(2026, 3, 10, 9, 30));
    await setup.h.close();
  });

  /// A 09:00-10:00, a gap, then B 11:00-12:00.
  Future<({TimelineHarness h, String a, String b})> twoApart() async {
    final h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9));
    final first = await h.writer.startByName(name: 'A');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.stop();
    h.clock.advance(const Duration(hours: 1));
    final second = await h.writer.startByName(name: 'B');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.stop();
    return (h: h, a: first.entryId, b: second.entryId);
  }

  test('an overlap across a gap trims the neighbour, on every path', () async {
    final results = <String>[];
    final reach = DateTime.utc(2026, 3, 10, 9, 30);

    {
      final setup = await twoApart();
      await setup.h.writer.moveBoundary(
        entryId: setup.b,
        edge: BoundaryEdge.start,
        desired: reach,
        snap: snap,
      );
      results.add(shape(await setup.h.entries()));
      await setup.h.close();
    }

    {
      final setup = await twoApart();
      await setup.h.writer.setEntryTimes(
        entryId: setup.b,
        startUtc: reach,
        endUtc: (await setup.h.byId(setup.b)).endUtc,
      );
      expect((await setup.h.byId(setup.a)).endUtc, reach);
      results.add(shape(await setup.h.entries()));
      await setup.h.close();
    }

    expect(results.toSet(), hasLength(1), reason: 'SPEC §14.5');
  });

  test('undo of an automatic trim restores both entries in one step', () async {
    final setup = await twoApart();
    final before = shape(await setup.h.entries());

    final undo = await setup.h.writer.setEntryTimes(
      entryId: setup.b,
      startUtc: DateTime.utc(2026, 3, 10, 9, 30),
      endUtc: (await setup.h.byId(setup.b)).endUtc,
    );
    await undo.undo();

    expect(shape(await setup.h.entries()), before, reason: 'SPEC §7.5');
    await setup.h.close();
  });

  test(
    'a typed trim that would leave the neighbour too short is refused',
    () async {
      final setup = await twoApart();
      final before = shape(await setup.h.entries());

      await expectLater(
        setup.h.writer.setEntryTimes(
          entryId: setup.b,
          // Thirty seconds of A would be left.
          startUtc: DateTime.utc(2026, 3, 10, 9, 0, 30),
          endUtc: (await setup.h.byId(setup.b)).endUtc,
        ),
        throwsA(isA<InvariantViolation>()),
      );

      expect(
        shape(await setup.h.entries()),
        before,
        reason: 'SPEC §4.6: a refused edit changes nothing',
      );
      await setup.h.close();
    },
  );

  test(
    'moving the running start earlier is allowed; its end is not editable',
    () async {
      final h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9));
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(hours: 1));
      final running = await h.writer.startByName(name: 'B');
      h.clock.advance(const Duration(minutes: 30));

      await h.writer.moveBoundary(
        entryId: running.entryId,
        edge: BoundaryEdge.start,
        desired: DateTime.utc(2026, 3, 10, 10, 15),
        snap: snap,
      );
      expect(
        (await h.byId(running.entryId)).startUtc,
        DateTime.utc(2026, 3, 10, 10, 15),
      );

      await expectLater(
        h.writer.moveBoundary(
          entryId: running.entryId,
          edge: BoundaryEdge.end,
          desired: DateTime.utc(2026, 3, 10, 11),
          snap: snap,
        ),
        throwsA(anything),
        reason: 'SPEC §7.4: the running entry always ends now',
      );
      await h.close();
    },
  );

  test('split then undo returns the timeline to one entry', () async {
    final h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9));
    final entry = await h.writer.startByName(name: 'Long task');
    h.clock.advance(const Duration(hours: 2));
    await h.writer.stop();
    final before = shape(await h.entries());

    final (:second, :undo) = await h.writer.split(
      entryId: entry.entryId,
      atUtc: DateTime.utc(2026, 3, 10, 10),
    );
    expect(second.startUtc, DateTime.utc(2026, 3, 10, 10));
    expect(await h.entries(), hasLength(2));

    await undo.undo();
    expect(shape(await h.entries()), before);
    await h.close();
  });

  group('theBoundaryBeforeTheRunningEntryIsEditable', () {
    // SPEC §14.5 for the entry you are most likely to want to fix: the one that
    // just ended. Its own end is shared with the running entry's start, and
    // §7.4 only makes the *running* entry's end uneditable -- everything about
    // its predecessor is fair game.

    test('its free start moves, by drag and by typing', () async {
      final results = <String>[];

      // Drag: the finger lands off-grid at 09:29 and snapping takes it to 09:30.
      {
        final setup = await oneFinishedThenRunning();
        await setup.h.writer.moveBoundary(
          entryId: setup.a.id,
          edge: BoundaryEdge.start,
          desired: DateTime.utc(2026, 3, 10, 9, 29),
          snap: snap,
        );
        expect(
          (await setup.h.running())!.id,
          setup.b.id,
          reason: 'editing its neighbour neither stopped it nor moved it',
        );
        results.add(shape(await setup.h.entries()));
        await setup.h.close();
      }

      // Typing: the exact instant, unsnapped.
      {
        final setup = await oneFinishedThenRunning();
        await setup.h.writer.setEntryTimes(
          entryId: setup.a.id,
          startUtc: DateTime.utc(2026, 3, 10, 9, 30),
          endUtc: setup.a.endUtc,
        );
        results.add(shape(await setup.h.entries()));
        await setup.h.close();
      }

      expect(
        results.first,
        contains('2026-03-10 09:30:00.000Z'),
        reason: 'the start really did move',
      );
      expect(
        results.toSet(),
        hasLength(1),
        reason: 'SPEC §14.5: both paths produce the same timeline',
      );
    });

    test('growing into the running entry trims its start', () async {
      final r = await oneFinishedThenRunning();
      await r.h.writer.moveBoundary(
        entryId: r.a.id,
        edge: BoundaryEdge.end,
        desired: DateTime.utc(2026, 3, 10, 10, 15),
        snap: snap,
      );

      final entries = await r.h.entries();
      expect(entries[0].endUtc, DateTime.utc(2026, 3, 10, 10, 15));
      expect(
        entries[1].startUtc,
        entries[0].endUtc,
        reason:
            'SPEC §7.4: an overlap trims the neighbour, and the running '
            'entry is no exception',
      );
      expect(entries[1].isRunning, isTrue);
      await r.h.close();
    });

    test('moving away from the running entry leaves it unless told', () async {
      final r = await oneFinishedThenRunning();
      final earlier = DateTime.utc(2026, 3, 10, 9, 45);

      await r.h.writer.moveBoundary(
        entryId: r.a.id,
        edge: BoundaryEdge.end,
        desired: earlier,
        snap: snap,
      );
      expect((await r.h.byId(r.b.id)).startUtc, r.b.startUtc);

      final other = await oneFinishedThenRunning();
      await other.h.writer.moveBoundary(
        entryId: other.a.id,
        edge: BoundaryEdge.end,
        desired: earlier,
        snap: snap,
        carryNeighbour: true,
      );
      expect((await other.h.byId(other.b.id)).startUtc, earlier);

      await r.h.close();
      await other.h.close();
    });

    test('typing across a gap trims the running start', () async {
      // A gap this time, so the boundary is free rather than shared.
      // A 09:00-09:30, gap, B 10:00-running.
      final h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9));
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.stop();
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.startByName(name: 'B');
      h.clock.advance(const Duration(hours: 2));
      final a = (await h.entries()).first;

      await h.writer.setEntryTimes(
        entryId: a.id,
        startUtc: a.startUtc,
        endUtc: DateTime.utc(2026, 3, 10, 10, 30),
      );

      final running = (await h.running())!;
      expect(running.startUtc, DateTime.utc(2026, 3, 10, 10, 30));
      await h.close();
    });
  });
}
