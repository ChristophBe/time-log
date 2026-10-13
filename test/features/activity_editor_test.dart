import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/entry/activity_editor.dart';
import 'package:time_log/src/features/entry/entry_sheet.dart';

import '../support/pump_app.dart';

/// SPEC §6.7: rename, recolour, merge — all undoable.
void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  const specs = Activity(id: 'a1', name: 'Writing specs', colorSeed: 0);
  final entry = TimeEntry(
    id: 'e1',
    activityId: 'a1',
    startUtc: DateTime.utc(2026, 3, 10, 13),
    endUtc: DateTime.utc(2026, 3, 10, 14),
    tzName: 'Europe/Berlin',
  );

  /// The editor's own Save: the entry sheet underneath has one too.
  final saveButton = find.descendant(
    of: find.byType(ActivityEditor),
    matching: find.widgetWithText(FilledButton, 'Save'),
  );

  Future<WidgetHarness> pumpEditor(WidgetTester tester) async {
    final h = WidgetHarness(
      now: now,
      activities: const <String, Activity>{'a1': specs},
      entries: <TimeEntry>[entry],
    );
    when(
      () => h.writer.renameActivity(
        activityId: any(named: 'activityId'),
        name: any(named: 'name'),
      ),
    ).thenAnswer(
      (_) async => (activity: specs, undo: UndoToken('x', () async {})),
    );
    when(
      () => h.writer.setActivityColor(
        activityId: any(named: 'activityId'),
        colorSeed: any(named: 'colorSeed'),
      ),
    ).thenAnswer((_) async => UndoToken('x', () async {}));
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
            onPressed: () => showEntrySheet(context, entry),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The activity name opens the picker now (SPEC §6.10); renaming for all of
    // history is one step further in, where it says so.
    await tester.tap(find.text('Writing specs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-picker-rename')));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('the picker\'s rename row opens the editor', (tester) async {
    await pumpEditor(tester);

    expect(find.byType(ActivityEditor), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('activity-name')))
          .controller!
          .text,
      'Writing specs',
    );
  });

  testWidgets('renaming goes through the writer, with undo', (tester) async {
    final h = await pumpEditor(tester);

    await tester.enterText(find.byKey(const Key('activity-name')), 'Specs');
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verify(() => h.writer.renameActivity(activityId: 'a1', name: 'Specs'))
        .called(1);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('a blank name cannot be saved', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byKey(const Key('activity-name')), '   ');
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('picking a colour goes through the writer, with undo', (
    tester,
  ) async {
    final h = await pumpEditor(tester);

    await tester.tap(find.bySemanticsLabel('Colour 4'));
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verify(() => h.writer.setActivityColor(activityId: 'a1', colorSeed: 3))
        .called(1);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('saving without changing anything writes nothing', (
    tester,
  ) async {
    final h = await pumpEditor(tester);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verifyNever(
      () => h.writer.renameActivity(
        activityId: any(named: 'activityId'),
        name: any(named: 'name'),
      ),
    );
    verifyNever(
      () => h.writer.setActivityColor(
        activityId: any(named: 'activityId'),
        colorSeed: any(named: 'colorSeed'),
      ),
    );
  });

  testWidgets('the editor meets SPEC §10', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpEditor(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
