import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/timeline_math.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/entry/entry_providers.dart';
import 'package:time_log/src/features/entry/entry_sheet.dart';

import '../support/pump_app.dart';

/// SPEC §8.4 in the entry sheet: typed times, steppers, note, split, delete,
/// and relabelling one span through the activity picker (SPEC §6.10).
/// call (SPEC §10.1, §14.5).
void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final specs = activityFor(id: 'a1', name: 'Writing specs');
  final email = activityFor(id: 'a2', name: 'Email', colorSeed: 3);
  final activities = <String, Activity>{specs.id: specs, email.id: email};

  // 13:00 to 14:00 UTC, an hour before now.
  final entry = entryFor(
    id: 'e1',
    activityId: specs.id,
    start: DateTime.utc(2026, 3, 10, 13),
    end: DateTime.utc(2026, 3, 10, 14),
  );

  setUpAll(() {
    registerFallbackValue(BoundaryEdge.start);
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(Duration.zero);
  });

  group('entry sheet (SPEC §8.4)', () {
    Future<WidgetHarness> pumpSheet(
      WidgetTester tester, {
      TimeEntry? target,
      EntryNeighbours neighbours = const (previous: null, next: null),
      Size surfaceSize = const Size(420, 900),
    }) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        entries: <TimeEntry>[target ?? entry],
        neighbours: neighbours,
      );
      when(
        () => h.writer.setEntryTimes(
          entryId: any(named: 'entryId'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
          carryPrevious: any(named: 'carryPrevious'),
          carryNext: any(named: 'carryNext'),
        ),
      ).thenAnswer((_) async => UndoToken('x', () async {}));
      when(() => h.writer.delete(any()))
          .thenAnswer((_) async => UndoToken('x', () async {}));
      when(
        () => h.writer.split(
          entryId: any(named: 'entryId'),
          atUtc: any(named: 'atUtc'),
        ),
      ).thenAnswer(
        (_) async => (
          second: TimeEntry(
            id: 'e2',
            activityId: entry.activityId,
            startUtc: DateTime.utc(2026, 3, 10, 13, 30),
            endUtc: entry.endUtc,
            tzName: entry.tzName,
          ),
          undo: UndoToken('x', () async {}),
        ),
      );
      when(
        () => h.writer.setEntryNote(
          entryId: any(named: 'entryId'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => UndoToken('x', () async {}));
      await h.pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEntrySheet(context, target ?? entry),
              child: const Text('open sheet'),
            ),
          ),
        ),
        surfaceSize: surfaceSize,
      );
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('the note is editable in place and commits itself', (
      tester,
    ) async {
      final noted = entryFor(
        id: 'e1',
        activityId: specs.id,
        start: DateTime.utc(2026, 3, 10, 13),
        end: DateTime.utc(2026, 3, 10, 14),
        note: 'chapter 3',
      );
      final h = await pumpSheet(tester, target: noted);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('entry-sheet-note')))
            .controller!
            .text,
        'chapter 3',
        reason: 'SPEC §8.4.1: the note is inline-editable, not read-only',
      );

      await tester.enterText(
        find.byKey(const Key('entry-sheet-note')),
        'chapter 4',
      );
      // Committing on focus loss, rather than through Save, is what makes one
      // note change one undo step instead of being bundled with a time change
      // (SPEC §7.5). Enter is not a commit: a note may want a second line.
      tester.binding.focusManager.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      verify(() => h.writer.setEntryNote(entryId: 'e1', note: 'chapter 4'))
          .called(1);
      expect(find.text('Note changed'), findsOneWidget);
    });

    testWidgets('the overflow menu keeps the Undo after the SnackBar goes', (
      tester,
    ) async {
      final h = await pumpSheet(tester);
      var undone = 0;
      when(
        () => h.writer.setEntryNote(
          entryId: any(named: 'entryId'),
          note: any(named: 'note'),
        ),
      ).thenAnswer(
        (_) async => UndoToken('Changed note', () async => undone++),
      );

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MenuItemButton>(
              find.widgetWithText(MenuItemButton, 'Nothing to undo'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('entry-sheet-note')), 'v2');
      tester.binding.focusManager.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      // SPEC §7.5: eight seconds in the SnackBar, the rest of the session here.
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text('Note changed'), findsNothing);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo: Changed note'));
      await tester.pumpAndSettle();

      expect(undone, 1);
      expect(find.text('Undone'), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nothing to undo'),
        findsOneWidget,
        reason: 'an Undo is spent once it is used',
      );
    });

    testWidgets('an unchanged note is not written', (tester) async {
      final h = await pumpSheet(tester);

      await tester.tap(find.byKey(const Key('entry-sheet-note')));
      await tester.pumpAndSettle();
      tester.binding.focusManager.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      verifyNever(
        () => h.writer.setEntryNote(
          entryId: any(named: 'entryId'),
          note: any(named: 'note'),
        ),
      );
    });

    testWidgets('shows start, end and duration', (tester) async {
      await pumpSheet(tester);

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      // A duration carries its units; the colon is reserved for the two clock
      // times above it (SPEC §9.8).
      expect(find.text('1 h'), findsOneWidget);
    });

    testWidgets('the end stepper changes the end and the duration together', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.tap(find.byTooltip('End 5 minutes later'));
      await tester.pumpAndSettle();

      expect(find.text('15:05'), findsOneWidget);
      // The point of the format rule, on one screen: 15:05 is a time of day,
      // 1 h 05 min is a length, and they no longer look alike.
      expect(find.text('1 h 05 min'), findsOneWidget, reason: 'SPEC §8.4');
    });

    testWidgets('the duration stepper moves the end, not the start', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.tap(find.byTooltip('Duration 5 minutes later'));
      await tester.pumpAndSettle();

      expect(find.text('14:00'), findsOneWidget, reason: 'start unchanged');
      expect(find.text('15:05'), findsOneWidget);
    });

    testWidgets('Save is disabled until something changes', (tester) async {
      await pumpSheet(tester);

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('End 5 minutes later'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('Save writes the typed times through the writer', (
      tester,
    ) async {
      final h = await pumpSheet(tester);

      await tester.tap(find.byTooltip('End 5 minutes later'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      verify(
        () => h.writer.setEntryTimes(
          entryId: 'e1',
          startUtc: DateTime.utc(2026, 3, 10, 13),
          endUtc: DateTime.utc(2026, 3, 10, 14, 5),
        ),
      ).called(1);
    });

    testWidgets('a trim below the minimum is named inline and blocks Save', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        neighbours: (
          // Only 12:55-13:00, touching our 13:00 start, so one step back would
          // swallow it whole.
          previous: entryFor(
            id: 'p',
            activityId: email.id,
            start: DateTime.utc(2026, 3, 10, 12, 55),
            end: DateTime.utc(2026, 3, 10, 13),
          ),
          next: null,
        ),
      );

      await tester.tap(find.byTooltip('Start 5 minutes earlier'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('entry-sheet-conflict')), findsOneWidget);
      expect(find.textContaining('would leave Email under'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
        reason: 'SPEC §7.2: a typed conflict is reported, not silently clamped',
      );
    });

    group('neighbours (SPEC §7.1)', () {
      final before = entryFor(
        id: 'p',
        activityId: email.id,
        start: DateTime.utc(2026, 3, 10, 12),
        end: DateTime.utc(2026, 3, 10, 13),
      );
      final after = entryFor(
        id: 'n',
        activityId: email.id,
        start: DateTime.utc(2026, 3, 10, 14),
        end: DateTime.utc(2026, 3, 10, 14, 30),
      );

      Future<void> tapSave(WidgetTester tester) async {
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
      }

      testWidgets('moving a touching end away asks; Adjust carries it', (
        tester,
      ) async {
        final h = await pumpSheet(
          tester,
          neighbours: (previous: null, next: after),
        );

        await tester.tap(find.byTooltip('End 5 minutes earlier'));
        await tester.pumpAndSettle();
        await tapSave(tester);

        expect(find.text('Also adjust Email?'), findsOneWidget);
        verifyNever(
          () => h.writer.setEntryTimes(
            entryId: any(named: 'entryId'),
            startUtc: any(named: 'startUtc'),
            endUtc: any(named: 'endUtc'),
            carryPrevious: any(named: 'carryPrevious'),
            carryNext: any(named: 'carryNext'),
          ),
        );

        await tester.tap(find.text('Adjust Email'));
        await tester.pumpAndSettle();

        verify(
          () => h.writer.setEntryTimes(
            entryId: 'e1',
            startUtc: DateTime.utc(2026, 3, 10, 13),
            endUtc: DateTime.utc(2026, 3, 10, 13, 55),
            carryNext: true,
          ),
        ).called(1);
      });

      testWidgets('Leave gap saves only this entry', (tester) async {
        final h = await pumpSheet(
          tester,
          neighbours: (previous: null, next: after),
        );

        await tester.tap(find.byTooltip('End 5 minutes earlier'));
        await tester.pumpAndSettle();
        await tapSave(tester);
        await tester.tap(find.text('Leave gap'));
        await tester.pumpAndSettle();

        verify(
          () => h.writer.setEntryTimes(
            entryId: 'e1',
            startUtc: DateTime.utc(2026, 3, 10, 13),
            endUtc: DateTime.utc(2026, 3, 10, 13, 55),
          ),
        ).called(1);
      });

      testWidgets('Cancel saves nothing and keeps the sheet open', (
        tester,
      ) async {
        final h = await pumpSheet(
          tester,
          neighbours: (previous: null, next: after),
        );

        await tester.tap(find.byTooltip('End 5 minutes earlier'));
        await tester.pumpAndSettle();
        await tapSave(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(
          () => h.writer.setEntryTimes(
            entryId: any(named: 'entryId'),
            startUtc: any(named: 'startUtc'),
            endUtc: any(named: 'endUtc'),
            carryPrevious: any(named: 'carryPrevious'),
            carryNext: any(named: 'carryNext'),
          ),
        );
        expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      });

      testWidgets('an overlap saves without asking', (tester) async {
        final h = await pumpSheet(
          tester,
          neighbours: (previous: null, next: after),
        );

        await tester.tap(find.byTooltip('End 5 minutes later'));
        await tester.pumpAndSettle();
        await tapSave(tester);

        expect(find.text('Also adjust Email?'), findsNothing);
        verify(
          () => h.writer.setEntryTimes(
            entryId: 'e1',
            startUtc: DateTime.utc(2026, 3, 10, 13),
            endUtc: DateTime.utc(2026, 3, 10, 14, 5),
          ),
        ).called(1);
      });

      testWidgets('detaching both asks twice, then writes once', (
        tester,
      ) async {
        final h = await pumpSheet(
          tester,
          neighbours: (previous: before, next: after),
        );

        await tester.tap(find.byTooltip('Start 5 minutes later'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('End 5 minutes earlier'));
        await tester.pumpAndSettle();
        await tapSave(tester);

        await tester.tap(find.text('Adjust Email'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leave gap'));
        await tester.pumpAndSettle();

        verify(
          () => h.writer.setEntryTimes(
            entryId: 'e1',
            startUtc: DateTime.utc(2026, 3, 10, 13, 5),
            endUtc: DateTime.utc(2026, 3, 10, 13, 55),
            carryPrevious: true,
          ),
        ).called(1);
      });

      testWidgets('cancelling the second question writes nothing', (
        tester,
      ) async {
        final h = await pumpSheet(
          tester,
          neighbours: (previous: before, next: after),
        );

        await tester.tap(find.byTooltip('Start 5 minutes later'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('End 5 minutes earlier'));
        await tester.pumpAndSettle();
        await tapSave(tester);

        await tester.tap(find.text('Adjust Email'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(
          () => h.writer.setEntryTimes(
            entryId: any(named: 'entryId'),
            startUtc: any(named: 'startUtc'),
            endUtc: any(named: 'endUtc'),
            carryPrevious: any(named: 'carryPrevious'),
            carryNext: any(named: 'carryNext'),
          ),
        );
      });
    });

    testWidgets('Delete removes the entry and offers Undo', (tester) async {
      final h = await pumpSheet(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      verify(() => h.writer.delete('e1')).called(1);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('Split asks where, starting from the midpoint', (tester) async {
      // SPEC §6.6 splits at a chosen instant. The midpoint is the picker's
      // opening value, not the answer. A wider surface, because Material's
      // time picker dialog does not fit a 420dp one.
      final h = await pumpSheet(tester, surfaceSize: const Size(700, 900));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Split here…'));
      await tester.pumpAndSettle();

      expect(
        find.byType(TimePickerDialog),
        findsOneWidget,
        reason: 'it asks before it cuts',
      );
      verifyNever(
        () => h.writer.split(
          entryId: any(named: 'entryId'),
          atUtc: any(named: 'atUtc'),
        ),
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      verify(
        () => h.writer.split(
          entryId: 'e1',
          atUtc: DateTime.utc(2026, 3, 10, 13, 30),
        ),
      ).called(1);
    });

    testWidgets('a split opens the sheet on the second half (SPEC §6.6)', (
      tester,
    ) async {
      await pumpSheet(tester, surfaceSize: const Size(700, 900));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Split here…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(tester.widget<EntrySheet>(find.byType(EntrySheet)).entry.id, 'e2');
    });

    testWidgets('the activity name shows it can be edited', (tester) async {
      await pumpSheet(tester);

      expect(
        find.descendant(
          of: find.byType(EntrySheet),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Change activity'), findsOneWidget);
    });

    testWidgets('a cancelled split cuts nothing', (tester) async {
      final h = await pumpSheet(tester, surfaceSize: const Size(700, 900));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Split here…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => h.writer.split(
          entryId: any(named: 'entryId'),
          atUtc: any(named: 'atUtc'),
        ),
      );
    });

    testWidgets('the running entry shows no end field and cannot be split', (
      tester,
    ) async {
      final running = entryFor(
        id: 'r1',
        activityId: specs.id,
        start: DateTime.utc(2026, 3, 10, 13),
      );
      await pumpSheet(tester, target: running);

      expect(find.text('running'), findsOneWidget);
      expect(find.byTooltip('End 5 minutes later'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Split here…'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Resume'), findsNothing);
    });

    testWidgets('renders at 2x text scale without overflow', (tester) async {
      final h = WidgetHarness(now: now, activities: activities);
      await h.pump(
        tester,
        Scaffold(body: EntrySheet(entry: entry)),
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull);
    });
  });

  /// Relabelling one span, which is a different action from renaming the
  /// activity (SPEC §6.7) even though both start from the same tap.
  group('activity picker (SPEC §6.10)', () {
    Future<WidgetHarness> pumpPicker(
      WidgetTester tester, {
      TimeEntry? target,
      bool withUnsavedStart = false,
    }) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        entries: <TimeEntry>[target ?? entry],
        suggestions: <ActivitySuggestion>[
          suggestionFor(
            activity: email,
            lastUsed: now.subtract(const Duration(hours: 2)),
          ),
        ],
      );
      when(
        () => h.writer.setEntryActivity(
          entryId: any(named: 'entryId'),
          name: any(named: 'name'),
        ),
      ).thenAnswer(
        (invocation) async =>
            (activity: email, undo: UndoToken('x', () async {})),
      );
      when(
        () => h.writer.setEntryNote(
          entryId: any(named: 'entryId'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => UndoToken('x', () async {}));
      when(
        () => h.writer.setEntryTimes(
          entryId: any(named: 'entryId'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => UndoToken('x', () async {}));
      await h.pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEntrySheet(context, target ?? entry),
              child: const Text('open sheet'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      if (withUnsavedStart) {
        await tester.tap(find.byTooltip('Start 5 minutes later'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Writing specs'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('the activity name opens the picker, not the renamer', (
      tester,
    ) async {
      await pumpPicker(tester);

      expect(find.text('Change activity'), findsWidgets);
      expect(
        find.text('This entry only — currently Writing specs.'),
        findsOneWidget,
        reason: 'SPEC §6.10: the two edits have to be told apart',
      );
      // The §6.7 route is still here, one step further in and labelled.
      expect(find.byKey(const Key('activity-picker-rename')), findsOneWidget);
    });

    testWidgets('the entry\'s own activity is not offered', (tester) async {
      await pumpPicker(tester);

      expect(
        find.byKey(const ValueKey<String>('picker-suggestion-a2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('picker-suggestion-a1')),
        findsNothing,
        reason: 'SPEC §9.6: picking it would be a no-op',
      );
    });

    testWidgets(
      'picking a suggestion relabels the entry and closes the sheet',
      (tester) async {
        final h = await pumpPicker(tester);

        await tester.tap(
          find.byKey(const ValueKey<String>('picker-suggestion-a2')),
        );
        await tester.pumpAndSettle();

        verify(() => h.writer.setEntryActivity(entryId: 'e1', name: 'Email'))
            .called(1);
        expect(find.text('Changed to Email'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
        expect(
          find.byType(EntrySheet),
          findsNothing,
          reason: 'the sheet was built from an entry that has moved',
        );
      },
    );

    testWidgets('a relabel keeps unsaved times, and Save still applies them', (
      tester,
    ) async {
      final h = await pumpPicker(tester, withUnsavedStart: true);

      await tester.tap(
        find.byKey(const ValueKey<String>('picker-suggestion-a2')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(EntrySheet),
        findsOneWidget,
        reason: 'SPEC §8.4: closing would silently drop the edit',
      );
      expect(
        find.descendant(
          of: find.byType(EntrySheet),
          matching: find.text('Email'),
        ),
        findsOneWidget,
        reason: 'the header follows the relabel',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      verify(
        () => h.writer.setEntryTimes(
          entryId: 'e1',
          startUtc: entry.startUtc.add(const Duration(minutes: 5)),
          endUtc: entry.endUtc,
        ),
      ).called(1);
      expect(find.byType(EntrySheet), findsNothing);
    });

    testWidgets('a typed name that matches nothing creates it', (tester) async {
      final h = await pumpPicker(tester);

      await tester.enterText(
        find.byKey(const Key('activity-name-field')),
        'Reading',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('activity-name-commit')));
      await tester.pumpAndSettle();

      verify(() => h.writer.setEntryActivity(entryId: 'e1', name: 'Reading'))
          .called(1);
    });

    testWidgets('a blank name cannot be committed', (tester) async {
      await pumpPicker(tester);

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('activity-name-commit')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('arrow down then Enter picks the first suggestion', (
      tester,
    ) async {
      final h = await pumpPicker(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      verify(() => h.writer.setEntryActivity(entryId: 'e1', name: 'Email'))
          .called(1);
    });

    testWidgets('relabelling the running entry is offered', (tester) async {
      final running = entryFor(
        id: 'r1',
        activityId: specs.id,
        start: DateTime.utc(2026, 3, 10, 13),
      );
      final h = await pumpPicker(tester, target: running);

      await tester.tap(
        find.byKey(const ValueKey<String>('picker-suggestion-a2')),
      );
      await tester.pumpAndSettle();

      verify(() => h.writer.setEntryActivity(entryId: 'r1', name: 'Email'))
          .called(1);
    });

    testWidgets('the name carries a hint naming both edits (SPEC §10.4)', (
      tester,
    ) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        entries: <TimeEntry>[entry],
      );
      await h.pump(tester, Scaffold(body: EntrySheet(entry: entry)));

      final hints = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((widget) => widget.properties.hint)
          .whereType<String>();
      expect(hints, contains('Double tap to change, rename or recolour'));
    });
  });
}
