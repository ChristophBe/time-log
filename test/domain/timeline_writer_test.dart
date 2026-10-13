import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';
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

  group('SPEC §6.10 change an entry\'s activity', () {
    /// Two finished entries, 'Writing specs' then 'Email'. Every test here
    /// relabels the first.
    Future<({String specs, String email})> twoEntries() async {
      final first = await h.writer.startByName(
        name: 'Writing specs',
        note: 'chapter 3',
      );
      h.clock.advance(const Duration(hours: 1));
      final second = await h.writer.startByName(name: 'Email');
      h.clock.advance(const Duration(minutes: 10));
      await h.writer.stop();
      return (specs: first.entryId, email: second.entryId);
    }

    Future<List<String>> activityNames() async {
      final rows = await h.db.select(h.db.activities).get();
      return rows.map((r) => r.name).toList()..sort();
    }

    test('relabelKeepsTimesAndNote', () async {
      final entryId = (await twoEntries()).specs;
      final before = await h.byId(entryId);

      await h.writer.setEntryActivity(entryId: entryId, name: 'Email');

      final after = await h.byId(entryId);
      expect(await h.activityNameOf(after), 'Email');
      expect(after.startUtc, before.startUtc);
      expect(
        after.endUtc,
        before.endUtc,
        reason: 'SPEC §6.10: a relabel moves nothing on the timeline',
      );
      expect(after.note, 'chapter 3');
    });

    test('relabelResolvesAnExistingActivityByNameKey', () async {
      final ids = await twoEntries();
      final entryId = ids.specs;
      final target = await h.byId(ids.email);

      // Different case and padding, same activity (SPEC §5.1).
      final result = await h.writer.setEntryActivity(
        entryId: entryId,
        name: '  EMAIL  ',
      );

      expect(result.activity.id, target.activityId);
      expect(await activityNames(), <String>[
        'Email',
        'Writing specs',
      ], reason: 'no second Email was created');
    });

    test('relabelCreatesTheActivityWhenTheNameIsNew', () async {
      final entryId = (await twoEntries()).specs;

      final result = await h.writer.setEntryActivity(
        entryId: entryId,
        name: 'Reading',
      );

      expect(result.activity.name, 'Reading');
      expect((await h.byId(entryId)).activityId, result.activity.id);
      expect(await activityNames(), <String>[
        'Email',
        'Reading',
        'Writing specs',
      ]);
    });

    test('relabelIsUndoable', () async {
      final entryId = (await twoEntries()).specs;
      final before = await h.byId(entryId);

      final toExisting = await h.writer.setEntryActivity(
        entryId: entryId,
        name: 'Email',
      );
      await toExisting.undo!.undo();

      expect((await h.byId(entryId)).activityId, before.activityId);
      expect(await activityNames(), <String>[
        'Email',
        'Writing specs',
      ], reason: 'undoing must not drop an activity it did not create');

      final toNew = await h.writer.setEntryActivity(
        entryId: entryId,
        name: 'Reading',
      );
      await toNew.undo!.undo();

      expect((await h.byId(entryId)).activityId, before.activityId);
      expect(await activityNames(), <String>[
        'Email',
        'Writing specs',
      ], reason: 'the activity the relabel created goes back out with it');
    });

    test('relabelIsUndoableButKeepsAnActivitySomethingElseStartedUsing', () async {
      final entryId = (await twoEntries()).specs;
      final relabel = await h.writer.setEntryActivity(
        entryId: entryId,
        name: 'Reading',
      );

      // Something else picked the new activity up in the meantime, so taking it
      // back out would break `activity_id`'s foreign key.
      await h.writer.startByName(name: 'Reading');
      await relabel.undo!.undo();

      expect(await activityNames(), <String>[
        'Email',
        'Reading',
        'Writing specs',
      ]);
    });

    test('relabelToTheSameActivityChangesNothing', () async {
      final entryId = (await twoEntries()).specs;
      final before = await h.byId(entryId);

      final result = await h.writer.setEntryActivity(
        entryId: entryId,
        name: 'writing SPECS',
      );

      expect(
        result.undo,
        isNull,
        reason: 'SPEC §6.10: nothing was written, so there is nothing to undo',
      );
      expect(await h.byId(entryId), before);
    });

    test('relabelWorksOnTheRunningEntry', () async {
      final started = await h.writer.startByName(name: 'Writing specs');
      h.clock.advance(const Duration(minutes: 20));
      final before = await h.byId(started.entryId);

      await h.writer.setEntryActivity(entryId: started.entryId, name: 'Email');

      final after = await h.byId(started.entryId);
      expect(await h.activityNameOf(after), 'Email');
      expect(after.isRunning, isTrue, reason: 'SPEC §4.1 is untouched');
      expect(after.startUtc, before.startUtc);
      expect((await h.running())!.id, started.entryId);
    });

    test('an unusable name is refused', () async {
      final entryId = (await twoEntries()).specs;

      await expectLater(
        h.writer.setEntryActivity(entryId: entryId, name: '   '),
        throwsArgumentError,
      );
      expect(await activityNames(), <String>['Email', 'Writing specs']);
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

  group('SPEC §6.11 day rollover', () {
    // Contiguous UTC days, so a cut lands where the test says it does whatever
    // zone the machine running it is in.
    DayWindowCalculator calendar(List<Duration> lengths, {DateTime? from}) {
      final windows = <DayWindow>[];
      var start = from ?? DateTime.utc(2026, 3, 10);
      for (var i = 0; i < lengths.length; i++) {
        final local = start.toUtc();
        windows.add(
          DayWindow(
            startUtc: start,
            endUtc: start.add(lengths[i]),
            year: local.year,
            month: local.month,
            day: local.day,
          ),
        );
        start = start.add(lengths[i]);
      }
      return FixedDayWindowCalculator(windows);
    }

    DayWindowCalculator days(int count) =>
        calendar(List<Duration>.filled(count, const Duration(hours: 24)));

    /// A run started at 22:00 on the 10th, with the clock now at [now].
    Future<void> runningSince22(DateTime now, {String? note}) async {
      h.clock.setTo(DateTime.utc(2026, 3, 10, 22));
      await h.writer.startByName(name: 'Writing specs', note: note);
      h.clock.setTo(now);
    }

    test('runningEntryIsCutAtMidnight', () async {
      await runningSince22(DateTime.utc(2026, 3, 11, 6));
      final outcome = await h.writer.rollOverRunningEntry(days: days(3));

      expect(outcome.boundaries, <DateTime>[DateTime.utc(2026, 3, 11)]);
      final entries = await h.entries();
      expect(entries, hasLength(2));
      expect(entries[0].startUtc, DateTime.utc(2026, 3, 10, 22));
      expect(entries[0].endUtc, DateTime.utc(2026, 3, 11));
      expect(
        entries[1].startUtc,
        entries[0].endUtc,
        reason: 'SPEC §4.4: the cut instant is shared exactly',
      );
      expect(entries[1].isRunning, isTrue);
      expect(outcome.runningEntryId, entries[1].id);
    });

    test('rollOverRestartsTheSameActivityAndNote', () async {
      await runningSince22(DateTime.utc(2026, 3, 11, 6), note: 'release prep');
      await h.writer.rollOverRunningEntry(days: days(3));

      final entries = await h.entries();
      expect(entries[0].activityId, entries[1].activityId);
      expect(entries[1].note, 'release prep');
      expect(await h.activityNameOf(entries[1]), 'Writing specs');
    });

    test('rollOverBackfillsEveryMissedMidnight', () async {
      // Started on a Friday evening, reopened on the Monday morning.
      await runningSince22(DateTime.utc(2026, 3, 13, 9));
      await h.writer.rollOverRunningEntry(days: days(5));

      final entries = await h.entries();
      expect(entries, hasLength(4));
      expect(entries[0].endUtc, DateTime.utc(2026, 3, 11));
      expect(entries[1].endUtc, DateTime.utc(2026, 3, 12));
      expect(entries[2].endUtc, DateTime.utc(2026, 3, 13));
      expect(entries[3].startUtc, DateTime.utc(2026, 3, 13));
      expect(entries.where((e) => e.isRunning), hasLength(1));
      expect(
        entries[1].durationAt(h.now),
        const Duration(hours: 24),
        reason: 'a whole day in the middle is a whole entry',
      );
    });

    test('rollOverKeepsTheSubMinuteScrapBeforeMidnight', () async {
      h.clock.setTo(DateTime.utc(2026, 3, 10, 23, 59, 40));
      await h.writer.startByName(name: 'Writing specs');
      h.clock.setTo(DateTime.utc(2026, 3, 11, 0, 30));
      await h.writer.rollOverRunningEntry(days: days(3));

      final entries = await h.entries();
      expect(entries, hasLength(2));
      expect(
        entries[0].durationAt(h.now),
        const Duration(seconds: 20),
        reason: 'SPEC §4.3: the minimum constrains editing, not storage',
      );
    });

    test('rollOverConservesTotalTrackedTime', () async {
      await runningSince22(DateTime.utc(2026, 3, 12, 6));
      final before = await h.totalTracked();
      await h.writer.rollOverRunningEntry(days: days(4));

      expect(await h.totalTracked(), before);
      expect(before, const Duration(hours: 32));
    });

    test('rollOverIsIdempotent', () async {
      await runningSince22(DateTime.utc(2026, 3, 11, 6));
      await h.writer.rollOverRunningEntry(days: days(3));
      final after = await h.entries();

      final again = await h.writer.rollOverRunningEntry(days: days(3));
      expect(again.changedAnything, isFalse);
      expect(await h.entries(), after);
    });

    test('rollOverDoesNothingWhenNothingIsRunning', () async {
      h.clock.setTo(DateTime.utc(2026, 3, 10, 22));
      await h.writer.startByName(name: 'Writing specs');
      h.clock.setTo(DateTime.utc(2026, 3, 11, 6));
      await h.writer.stop();
      final before = await h.entries();
      expect(before.single.startUtc.day, 10);
      expect(before.single.endUtc!.day, 11);

      final outcome = await h.writer.rollOverRunningEntry(days: days(3));
      expect(outcome.changedAnything, isFalse);
      expect(outcome.runningEntryId, isNull);
      expect(
        await h.entries(),
        before,
        reason: 'a finished entry that crosses midnight stays one row (§5.3)',
      );
    });

    test('rollOverFollowsDstDayLength', () async {
      await runningSince22(DateTime.utc(2026, 3, 11, 6));
      // A 25-hour day: midnight is an hour later than +24h would put it.
      await h.writer.rollOverRunningEntry(
        days: calendar(<Duration>[
          const Duration(hours: 25),
          const Duration(hours: 24),
          const Duration(hours: 24),
        ], from: DateTime.utc(2026, 3, 10)),
      );

      final entries = await h.entries();
      expect(
        entries[0].endUtc,
        DateTime.utc(2026, 3, 11, 1),
        reason: 'SPEC §5.3: the day window is 25 hours long, so the cut is too',
      );
    });

    test('a run older than a year is closed and not restarted', () async {
      await runningSince22(DateTime.utc(2027, 4, 1, 9));
      final outcome = await h.writer.rollOverRunningEntry(days: days(400));

      expect(outcome.boundaries, <DateTime>[DateTime.utc(2026, 3, 11)]);
      expect(outcome.runningEntryId, isNull);
      final entries = await h.entries();
      expect(entries, hasLength(1));
      expect(entries.single.endUtc, DateTime.utc(2026, 3, 11));
      expect(
        await h.running(),
        isNull,
        reason: 'SPEC §6.11: a forgotten clock is not 400 days of work',
      );
    });

    test('the run start follows the chain back across the cuts', () async {
      await runningSince22(DateTime.utc(2026, 3, 12, 6));
      await h.writer.rollOverRunningEntry(days: days(4));

      final running = (await h.running())!;
      expect(running.startUtc, DateTime.utc(2026, 3, 12));
      expect(
        await h.repository.runStartOf(running, days: days(4)),
        DateTime.utc(2026, 3, 10, 22),
        reason: 'SPEC §8.1: the long-run banner measures the whole run',
      );
    });

    test('the run start stops at a different activity', () async {
      await runningSince22(DateTime.utc(2026, 3, 11, 6));
      await h.writer.rollOverRunningEntry(days: days(3));
      // Switching activities on the new day ends the run, cut or no cut.
      h.clock.setTo(DateTime.utc(2026, 3, 11, 7));
      await h.writer.startByName(name: 'Email');

      final running = (await h.running())!;
      expect(
        await h.repository.runStartOf(running, days: days(3)),
        DateTime.utc(2026, 3, 11, 7),
      );
    });
  });
}
