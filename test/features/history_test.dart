import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/entry/entry_sheet.dart';
import 'package:time_log/src/features/history/history_screen.dart';

import '../support/pump_app.dart';

/// SPEC §8.5.
void main() {
  final now = DateTime.utc(2026, 3, 11, 12);
  const specs = Activity(id: 'a1', name: 'Writing specs', colorSeed: 0);
  const email = Activity(id: 'a2', name: 'Email', colorSeed: 1);
  const activities = <String, Activity>{'a1': specs, 'a2': email};

  TimeEntry entry({
    required String id,
    required String activityId,
    required DateTime start,
    DateTime? end,
    String? note,
  }) => TimeEntry(
    id: id,
    activityId: activityId,
    startUtc: start,
    endUtc: end ?? start.add(const Duration(hours: 1)),
    tzName: 'Europe/Berlin',
    note: note,
  );

  List<TimeEntry> twoDays() => <TimeEntry>[
    entry(
      id: 'e1',
      activityId: 'a1',
      start: DateTime.utc(2026, 3, 10, 9),
      note: 'chapter 3',
    ),
    entry(id: 'e2', activityId: 'a2', start: DateTime.utc(2026, 3, 10, 14)),
    entry(id: 'e3', activityId: 'a1', start: DateTime.utc(2026, 3, 11, 9)),
  ];

  Future<WidgetHarness> pumpHistory(
    WidgetTester tester, {
    List<TimeEntry>? entries,
  }) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      entries: entries ?? twoDays(),
    );
    when(() => h.writer.delete(any()))
        .thenAnswer((_) async => UndoToken('x', () async {}));
    await h.pump(tester, const HistoryScreen());
    return h;
  }

  testWidgets('entries are grouped by day with that day\'s total', (
    tester,
  ) async {
    await pumpHistory(tester);

    expect(find.text('Wed, Mar 11, 2026'), findsOneWidget);
    expect(find.text('Tue, Mar 10, 2026'), findsOneWidget);
    // The 10th has two hour-long entries; the same function the day header
    // uses produced this, so the two can never disagree.
    expect(find.text('2 h'), findsOneWidget);
    expect(find.text('1 h'), findsOneWidget);
  });

  testWidgets('a row shows its range, duration and note', (tester) async {
    await pumpHistory(tester);

    expect(
      find.textContaining('chapter 3'),
      findsOneWidget,
      reason: 'the note is what tells two spans of one activity apart',
    );
    expect(find.textContaining('1 h'), findsWidgets);
  });

  testWidgets('search covers both the activity name and the note', (
    tester,
  ) async {
    await pumpHistory(tester);

    // Scoped to the rows: the filter chips carry the same names.
    await tester.enterText(find.byKey(const Key('history-search')), 'chapter');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Writing specs'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Email'), findsNothing);

    await tester.enterText(find.byKey(const Key('history-search')), 'email');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Email'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Writing specs'), findsNothing);
  });

  testWidgets('a search that matches nothing says so', (tester) async {
    await pumpHistory(tester);

    await tester.enterText(find.byKey(const Key('history-search')), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches'), findsOneWidget);
  });

  testWidgets('the activity filter narrows the list', (tester) async {
    await pumpHistory(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Email'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Email'), findsWidgets);
    expect(
      find.widgetWithText(ListTile, 'Writing specs'),
      findsNothing,
      reason: 'filtered out',
    );
  });

  testWidgets('an empty history explains itself', (tester) async {
    await pumpHistory(tester, entries: const <TimeEntry>[]);

    expect(find.text('Nothing tracked yet'), findsOneWidget);
  });

  testWidgets('tapping a row opens its entry sheet', (tester) async {
    await pumpHistory(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Email'));
    await tester.pumpAndSettle();

    expect(find.byType(EntrySheet), findsOneWidget);
  });

  testWidgets('the row menu deletes, with undo (SPEC §10.1)', (tester) async {
    // The non-gesture equivalent of the swipe, which is what §10.1 requires.
    final h = await pumpHistory(tester);

    await tester.tap(find.byTooltip('Entry actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    verify(() => h.writer.delete(any())).called(1);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('swiping a row deletes it too', (tester) async {
    final h = await pumpHistory(tester);

    await tester.drag(
      find.widgetWithText(ListTile, 'Email'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    verify(() => h.writer.delete('e2')).called(1);
  });

  testWidgets('earlier months load on request', (tester) async {
    final h = await pumpHistory(tester);

    await tester.tap(find.text('Load earlier months'));
    await tester.pumpAndSettle();

    // A wider window is asked of the database, which is what paging by month
    // means here (SPEC §8.5).
    verify(() => h.entryRepository.watchEntriesInRange(any(), any()))
        .called(greaterThan(1));
  });

  testWidgets('meets SPEC §10 on labelling, targets and contrast', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHistory(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('renders at 2x text scale without overflow', (tester) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      entries: twoDays(),
    );
    await h.pump(
      tester,
      const HistoryScreen(),
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
  });
}
