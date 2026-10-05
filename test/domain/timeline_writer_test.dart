import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/invariants.dart';
import 'package:time_log/src/domain/timeline_writer.dart';

import '../support/fixtures.dart';

/// Each test here is one of the invariants in SPEC §4 or one of the actions in
/// SPEC §6. The names match the test list in SPEC §12.
void main() {
  late TimelineHarness h;

  setUp(() => h = TimelineHarness());
  tearDown(() => h.close());

  group('SPEC §4 invariants', () {
    test('startingWhileRunningLeavesNoGap', () async {
      await h.writer.startByName(name: 'Writing specs');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.startByName(name: 'Email');

      final entries = await h.entries();
      expect(entries, hasLength(2));
      expect(
        entries[0].endUtc,
        entries[1].startUtc,
        reason: 'SPEC §4.4: the handover instant is shared exactly',
      );
      expect(entries[1].isRunning, isTrue);
    });

    test('onlyOneRunningEntryEverExists', () async {
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 10));
      await h.writer.startByName(name: 'B');
      h.clock.advance(const Duration(minutes: 10));
      await h.writer.startByName(name: 'C');

      final running = await h.db.runningEntry().get();
      expect(running, hasLength(1));
    });

    test('noEntryOverlapsAnother across a long session', () async {
      for (final name in <String>['A', 'B', 'C', 'D']) {
        await h.writer.startByName(name: name);
        h.clock.advance(const Duration(minutes: 7));
      }
      final entries = await h.entries();
      for (var i = 0; i < entries.length - 1; i++) {
        expect(
          entries[i].endUtc!.isAfter(entries[i + 1].startUtc),
          isFalse,
          reason: 'SPEC §4.2',
        );
      }
    });

    test('failedMutationChangesNothing', () async {
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 20));
      final stop = await h.writer.stop();
      final before = await h.entries();

      // Splitting outside the entry is illegal, and must leave no trace.
      await expectLater(
        h.writer.split(
          entryId: stop.entryId!,
          atUtc: h.now.add(const Duration(hours: 5)),
        ),
        throwsA(isA<InvariantViolation>()),
      );
      expect(await h.entries(), before, reason: 'SPEC §4.6: rolled back whole');
    });

    test('noFutureStarts is rejected', () async {
      final start = await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.stop();
      // Move the clock backwards so the entry now sits in the future.
      h.clock.setTo(DateTime.utc(2026, 3, 10, 8));
      await expectLater(
        h.writer.setEntryTimes(
          entryId: start.entryId,
          startUtc: DateTime.utc(2026, 3, 10, 12),
          endUtc: DateTime.utc(2026, 3, 10, 13),
        ),
        throwsA(isA<InvariantViolation>()),
      );
    });
  });

  group('SPEC §6.1 start', () {
    test('starting the same activity again is a no-op', () async {
      final first = await h.writer.startByName(name: 'Writing specs');
      h.clock.advance(const Duration(minutes: 5));
      final second = await h.writer.startByName(name: 'writing   SPECS');

      expect(second.mode, StartMode.alreadyRunning);
      expect(second.entryId, first.entryId);
      expect(await h.entries(), hasLength(1));
    });

    test(
      'activity names are matched case- and whitespace-insensitively',
      () async {
        await h.writer.startByName(name: 'Deep Work');
        h.clock.advance(const Duration(minutes: 30));
        await h.writer.startByName(name: 'Email');
        h.clock.advance(const Duration(minutes: 30));
        await h.writer.startByName(name: '  deep   work  ');

        final activities = await h.db.select(h.db.activities).get();
        expect(
          activities.map((a) => a.name),
          containsAll(<String>['Deep Work', 'Email']),
        );
        expect(activities, hasLength(2));
      },
    );

    test('subMinuteHandoverReplacesInsteadOfSplitting', () async {
      final misstart = await h.writer.startByName(name: 'Emial');
      final misstartBegan = h.now;
      h.clock.advance(const Duration(seconds: 3));
      final corrected = await h.writer.startByName(name: 'Email');

      expect(corrected.mode, StartMode.replacedMisstart);
      final entries = await h.entries();
      expect(entries, hasLength(1), reason: 'SPEC §6.1: no 3-second litter');
      expect(entries.single.id, corrected.entryId);
      expect(
        entries.single.startUtc,
        misstartBegan,
        reason: 'the correction inherits the mis-start time',
      );
      expect(await h.byId(misstart.entryId), isNotNull);
    });

    test('a replaced mis-start is restored by undo', () async {
      final misstart = await h.writer.startByName(name: 'Emial');
      h.clock.advance(const Duration(seconds: 3));
      final corrected = await h.writer.startByName(name: 'Email');
      await corrected.undo!.undo();

      final entries = await h.entries();
      expect(entries, hasLength(1));
      expect(entries.single.id, misstart.entryId);
      expect(entries.single.isRunning, isTrue);
    });

    test(
      'switching stores the stopped activity name for the message',
      () async {
        await h.writer.startByName(name: 'Writing specs');
        h.clock.advance(const Duration(minutes: 30));
        final outcome = await h.writer.startByName(name: 'Email');
        expect(outcome.mode, StartMode.switched);
        expect(outcome.stoppedActivityName, 'Writing specs');
      },
    );

    test('undo of a switch reopens the previous entry', () async {
      final first = await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      final second = await h.writer.startByName(name: 'B');
      await second.undo!.undo();

      final entries = await h.entries();
      expect(entries, hasLength(1));
      expect(entries.single.id, first.entryId);
      expect(entries.single.isRunning, isTrue, reason: 'A is running again');
    });

    test('an empty activity name is rejected', () async {
      await expectLater(
        h.writer.startByName(name: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SPEC §6.2 stop', () {
    test('stop records the exact instant', () async {
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 42));
      final outcome = await h.writer.stop();

      expect(outcome.stopped, isTrue);
      expect(outcome.duration, const Duration(minutes: 42));
      expect((await h.running()), isNull);
      expect((await h.entries()).single.endUtc, h.now);
    });

    test(
      'a sub-minute span is kept as-is and flagged, never rounded up',
      () async {
        await h.writer.startByName(name: 'A');
        h.clock.advance(const Duration(seconds: 20));
        final outcome = await h.writer.stop();

        expect(outcome.wasVeryShort, isTrue);
        expect(
          outcome.duration,
          const Duration(seconds: 20),
          reason: 'SPEC §6.2: recording a minute that did not happen would lie',
        );
      },
    );

    test('stop with nothing running is a no-op', () async {
      final outcome = await h.writer.stop();
      expect(outcome.stopped, isFalse);
      expect(outcome.undo, isNull);
    });

    test('stop refuses to record a backwards clock jump', () async {
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: -5));
      await expectLater(h.writer.stop(), throwsA(isA<InvariantViolation>()));
      expect(await h.running(), isNotNull, reason: 'still running, unchanged');
    });

    test('undo of stop makes the entry running again', () async {
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      final outcome = await h.writer.stop();
      await outcome.undo!.undo();
      expect((await h.running())?.id, outcome.entryId);
    });
  });

  group('SPEC §6.3 resume', () {
    test(
      'resume creates a new entry and leaves the original untouched',
      () async {
        final first = await h.writer.startByName(
          name: 'Writing specs',
          note: 'ch 3',
        );
        h.clock.advance(const Duration(minutes: 30));
        await h.writer.startByName(name: 'Email');
        h.clock.advance(const Duration(minutes: 15));

        final resumed = await h.writer.resume(first.entryId);
        final entries = await h.entries();

        expect(entries, hasLength(3));
        expect(resumed.entryId, isNot(first.entryId));
        final original = await h.byId(first.entryId);
        expect(
          original.endUtc,
          isNotNull,
          reason: 'the original span is intact',
        );
        final newEntry = await h.byId(resumed.entryId);
        expect(newEntry.activityId, original.activityId);
        expect(
          newEntry.note,
          'ch 3',
          reason: 'SPEC §6.3: the note is copied too',
        );
        expect(newEntry.isRunning, isTrue);
      },
    );

    test('resume stops whatever was running, with no gap', () async {
      final first = await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.startByName(name: 'B');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.resume(first.entryId);

      final entries = await h.entries();
      expect(entries[1].endUtc, entries[2].startUtc);
    });
  });

  group('SPEC §6.4 continue', () {
    const window = Duration(minutes: 5);

    test('continue reopens the entry rather than duplicating it', () async {
      final first = await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.stop();
      h.clock.advance(const Duration(minutes: 2));

      await h.writer.continueEntry(first.entryId, window: window);

      final entries = await h.entries();
      expect(entries, hasLength(1), reason: 'no adjacent clone was created');
      expect(entries.single.id, first.entryId);
      expect(entries.single.isRunning, isTrue);
    });

    test('continue is refused outside the window', () async {
      final first = await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.stop();
      h.clock.advance(const Duration(minutes: 10));

      await expectLater(
        h.writer.continueEntry(first.entryId, window: window),
        throwsA(isA<InvariantViolation>()),
      );
    });

    test('continue is refused when something else is running', () async {
      final first = await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.startByName(name: 'B');

      await expectLater(
        h.writer.continueEntry(first.entryId, window: window),
        throwsA(isA<InvariantViolation>()),
      );
    });

    test(
      'continue is refused for an entry that is not the most recent',
      () async {
        final first = await h.writer.startByName(name: 'A');
        h.clock.advance(const Duration(minutes: 30));
        await h.writer.startByName(name: 'B');
        h.clock.advance(const Duration(minutes: 30));
        await h.writer.stop();

        await expectLater(
          h.writer.continueEntry(first.entryId, window: window),
          throwsA(isA<InvariantViolation>()),
        );
      },
    );

    test('undo of continue restores the original end', () async {
      final first = await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      final stopped = await h.writer.stop();
      final endBefore = (await h.byId(first.entryId)).endUtc;
      h.clock.advance(const Duration(minutes: 2));

      final undo = await h.writer.continueEntry(first.entryId, window: window);
      await undo.undo();

      expect((await h.byId(first.entryId)).endUtc, endBefore);
      expect(stopped.stopped, isTrue);
    });
  });

  group('SPEC §6.6 split and §6.8 delete', () {
    test('split produces two touching halves with the same activity', () async {
      final entry = await h.writer.startByName(name: 'Long task', note: 'n');
      h.clock.advance(const Duration(hours: 2));
      await h.writer.stop();
      final at = (await h.byId(entry.entryId)).startUtc
          .add(const Duration(hours: 1));

      await h.writer.split(entryId: entry.entryId, atUtc: at);

      final entries = await h.entries();
      expect(entries, hasLength(2));
      expect(entries[0].endUtc, entries[1].startUtc, reason: 'they touch');
      expect(entries[0].activityId, entries[1].activityId);
      expect(entries[1].note, 'n');
    });

    test('deleteLeavesGapAndDoesNotStretchNeighbours', () async {
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      final middle = await h.writer.startByName(name: 'B');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.startByName(name: 'C');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.stop();

      final before = await h.entries();
      await h.writer.delete(middle.entryId);
      final after = await h.entries();

      expect(after, hasLength(2));
      expect(after[0].endUtc, before[0].endUtc, reason: 'SPEC §4.7');
      expect(after[1].startUtc, before[2].startUtc);
      expect(
        after[1].startUtc.difference(after[0].endUtc!),
        const Duration(minutes: 30),
        reason: 'the deletion leaves a visible gap',
      );
    });

    test('undo of delete brings the entry back', () async {
      await h.writer.startByName(name: 'A');
      h.clock.advance(const Duration(minutes: 30));
      final stopped = await h.writer.stop();
      final undo = await h.writer.delete(stopped.entryId!);
      expect(await h.entries(), isEmpty);

      await undo.undo();
      expect((await h.entries()).single.id, stopped.entryId);
    });
  });

  group('SPEC §8.4 notes', () {
    test('a note is set, replaced and undone', () async {
      final started = await h.writer.startByName(name: 'Writing specs');

      await h.writer.setEntryNote(entryId: started.entryId, note: 'chapter 3');
      expect((await h.byId(started.entryId)).note, 'chapter 3');

      final undo = await h.writer.setEntryNote(
        entryId: started.entryId,
        note: 'chapter 4',
      );
      expect((await h.byId(started.entryId)).note, 'chapter 4');

      await undo.undo();
      expect((await h.byId(started.entryId)).note, 'chapter 3');
    });

    test('an empty or blank note is stored as null, not as ""', () async {
      final started = await h.writer.startByName(
        name: 'Writing specs',
        note: 'something',
      );

      await h.writer.setEntryNote(entryId: started.entryId, note: '   ');

      expect(
        (await h.byId(started.entryId)).note,
        isNull,
        reason: '"has a note" must be one question, not two',
      );
    });

    test('a note is trimmed', () async {
      final started = await h.writer.startByName(name: 'Writing specs');

      await h.writer.setEntryNote(
        entryId: started.entryId,
        note: '  chapter 3  ',
      );

      expect((await h.byId(started.entryId)).note, 'chapter 3');
    });

    test('a note over the limit is refused', () async {
      final started = await h.writer.startByName(name: 'Writing specs');

      await expectLater(
        h.writer.setEntryNote(
          entryId: started.entryId,
          note: 'x' * (TimeEntry.maxNoteLength + 1),
        ),
        throwsArgumentError,
      );
      expect((await h.byId(started.entryId)).note, isNull);
    });

    test('a note leaves the times and the running slot alone', () async {
      final started = await h.writer.startByName(name: 'Writing specs');
      final before = await h.byId(started.entryId);

      await h.writer.setEntryNote(entryId: started.entryId, note: 'chapter 3');

      final after = await h.byId(started.entryId);
      expect(after.startUtc, before.startUtc);
      expect(after.endUtc, before.endUtc);
      expect(after.isRunning, isTrue);
    });
  });

  group('SPEC §6.7 activities', () {
    test('renaming to an existing name merges and re-points history', () async {
      final a = await h.writer.startByName(name: 'Emails');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.startByName(name: 'Email');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.stop();

      final original = await h.byId(a.entryId);
      final merged = await h.writer.renameActivity(
        activityId: original.activityId,
        name: 'Email',
      );

      final activities = await h.db.select(h.db.activities).get();
      expect(activities, hasLength(1));
      final entries = await h.entries();
      expect(entries.every((e) => e.activityId == merged.activity.id), isTrue);
    });

    test('a merge is undoable (SPEC §6.7)', () async {
      // The least reversible thing in the app: it re-points every entry and
      // drops an activity.
      final a = await h.writer.startByName(name: 'E-mail');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.startByName(name: 'Email');
      h.clock.advance(const Duration(minutes: 30));
      await h.writer.stop();
      final original = await h.byId(a.entryId);

      final merged = await h.writer.renameActivity(
        activityId: original.activityId,
        name: 'Email',
      );
      await merged.undo.undo();

      expect(await h.db.select(h.db.activities).get(), hasLength(2));
      expect(
        (await h.byId(a.entryId)).activityId,
        original.activityId,
        reason: 'the entry went back to the activity it came from',
      );
    });

    test('a rename is undoable (SPEC §6.7)', () async {
      final a = await h.writer.startByName(name: 'Writing spec');
      final original = await h.byId(a.entryId);

      final renamed = await h.writer.renameActivity(
        activityId: original.activityId,
        name: 'Writing specs',
      );
      expect(renamed.activity.name, 'Writing specs');

      await renamed.undo.undo();
      final back = await h.writer.renameActivity(
        activityId: original.activityId,
        name: 'Writing spec',
      );
      expect(back.activity.name, 'Writing spec');
    });

    test('a recolour is undoable (SPEC §6.7)', () async {
      final a = await h.writer.startByName(name: 'Writing specs');
      final entry = await h.byId(a.entryId);
      final before = (await h.db.select(h.db.activities).get()).single;

      final undo = await h.writer.setActivityColor(
        activityId: entry.activityId,
        colorSeed: 7,
      );
      expect((await h.db.select(h.db.activities).get()).single.colorSeed, 7);

      await undo.undo();
      expect(
        (await h.db.select(h.db.activities).get()).single.colorSeed,
        before.colorSeed,
      );
    });

    test('the first twelve activities get distinct colours', () async {
      for (var i = 0; i < 12; i++) {
        await h.writer.startByName(name: 'Activity $i');
        h.clock.advance(const Duration(minutes: 10));
      }
      final seeds = (await h.db.select(h.db.activities).get())
          .map((a) => a.colorSeed)
          .toSet();
      expect(seeds, hasLength(12));
    });
  });

  group('database-level guarantees', () {
    test('a second running entry cannot be forced in', () async {
      await h.writer.startByName(name: 'A');
      await expectLater(
        h.db.customStatement(
          'INSERT INTO time_entries (id, activity_id, start_utc, tz_name, '
          'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
          <Object>[
            'forced',
            (await h.running())!.activityId,
            h.now.millisecondsSinceEpoch + 1000,
            'UTC',
            0,
            0,
          ],
        ),
        throwsA(isA<SqliteException>()),
        reason: 'SPEC §4.1 is enforced by the schema, not only by the writer',
      );
    });
  });
}
