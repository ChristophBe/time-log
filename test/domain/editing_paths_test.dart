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
        );
      }
      results.add(shape(await setup.h.entries()));
      await setup.h.close();
    }

    // Path 3: typing exact times. Typed input is not snapped, and the sheet
    // writes the entry whose field was edited; moving the shared boundary means
    // both sides land on the typed instant.
    {
      final setup = await twoTouching();
      await setup.h.writer.setEntryTimes(
        entryId: setup.a.id,
        startUtc: setup.a.startUtc,
        endUtc: target,
      );
      await setup.h.writer.setEntryTimes(
        entryId: setup.b.id,
        startUtc: target,
        endUtc: setup.b.endUtc,
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

  test('typing a shared boundary carries the neighbour with it', () async {
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

  test('a typed time that would overlap across a gap is refused', () async {
    final h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9));
    final first = await h.writer.startByName(name: 'A');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.stop();
    // A gap, so B's start is a free boundary, not a shared one.
    h.clock.advance(const Duration(hours: 1));
    final second = await h.writer.startByName(name: 'B');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.stop();
    final before = shape(await h.entries());

    await expectLater(
      h.writer.setEntryTimes(
        entryId: second.entryId,
        // Reaches back into A, which is not adjacent and so is not carried.
        startUtc: DateTime.utc(2026, 3, 10, 9, 30),
        endUtc: (await h.byId(second.entryId)).endUtc,
      ),
      throwsA(isA<InvariantViolation>()),
    );

    expect(
      shape(await h.entries()),
      before,
      reason: 'SPEC §4.6: a refused edit changes nothing',
    );
    expect(first.entryId, isNotEmpty);
    await h.close();
  });

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

    final undo = await h.writer.split(
      entryId: entry.entryId,
      atUtc: DateTime.utc(2026, 3, 10, 10),
    );
    expect(await h.entries(), hasLength(2));

    await undo.undo();
    expect(shape(await h.entries()), before);
    await h.close();
  });
}
