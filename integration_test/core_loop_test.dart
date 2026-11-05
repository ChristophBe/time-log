import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_log/src/app/app.dart';
import 'package:time_log/src/core/clock.dart';
import 'package:time_log/src/data/db/database.dart';
import 'package:time_log/src/data/db/database_provider.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/backup/json_backup.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/timeline_writer.dart';

/// SPEC §12's integration suite: the core loop on real SQLite, on a real
/// device. Run it with:
///
///     flutter test integration_test -d <device>
///
/// The database is in memory on purpose. This builds with the app's own bundle
/// id, so `AppDatabase.open()` here would be the developer's real timeline.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Live entries, oldest first, straight from the database.
  Future<List<TimeEntryRow>> entries(AppDatabase db) =>
      (db.select(db.timeEntries)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
          .get();

  testWidgets('the core loop: start, switch, resume, correct, undo, relaunch', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 3, 10, 9));

    Widget app() => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appClockProvider.overrideWithValue(clock),
      ],
      child: const TimeLogApp(),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Start something.
    await tester.enterText(find.byKey(const Key('start-field')), 'Writing');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-button')));
    await tester.pumpAndSettle();
    expect(find.text('Writing'), findsWidgets);

    // Switch to something else: SPEC §4.4 says the handover leaves no gap. Any
    // sooner than this and the writer calls the first start a misstart and
    // replaces it. The undo bar has timed out by then, but not by this clock,
    // and left up it would take the tap: it sits over the Start button. An
    // hour, so the entry is drawn as a block rather than folded into the
    // short-entries chip (SPEC §8.2), which the keyboard step below needs.
    clock.advance(const Duration(hours: 1));
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();
    // Starting let go of the field, and enterText alone would not take it back.
    await tester.tap(find.byKey(const Key('start-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('start-field')), 'Email');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('stopped Writing'), findsOneWidget);

    // The handover instant is shared exactly (SPEC §4.4).
    var rows = await entries(db);
    expect(rows, hasLength(2));
    expect(rows[0].endUtc, rows[1].startUtc);

    // History has both of them, and resumes the first as a new entry
    // (SPEC §6.3): it is not the most recent, so there is nothing to continue.
    clock.advance(const Duration(minutes: 30));
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    final writingRow = find.widgetWithText(ListTile, 'Writing');
    expect(writingRow, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: writingRow,
        matching: find.byTooltip('Entry actions'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume').last);
    await tester.pumpAndSettle();
    rows = await entries(db);
    expect(rows, hasLength(3));
    expect(rows.last.endUtc, isNull, reason: 'Writing runs again');
    expect(rows.last.activityId, rows.first.activityId);

    // Correct a boundary by keyboard alone (SPEC §10.5, §14.5): the first
    // entry's start, which is free, one snap earlier. Then undo it (§7.5).
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    final firstStart = rows.first.startUtc;
    final block = find.byKey(ValueKey<String>('block-${rows.first.id}'));
    await tester.ensureVisible(block);
    await tester.pumpAndSettle();
    Focus.of(tester.element(block)).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
    await tester.pumpAndSettle();
    expect(
      (await entries(db)).first.startUtc,
      firstStart - const Duration(minutes: 5).inMilliseconds,
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await entries(db)).first.startUtc, firstStart);

    // And the running one is still running after a full rebuild, because a
    // running entry is nothing but a stored startUtc (SPEC §9.1).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('since'), findsOneWidget);
  });

  testWidgets('export, wipe and import give back the same timeline', (
    tester,
  ) async {
    // SPEC §12 and §14.10, on the device's own SQLite. The file pickers either
    // side of it are the platform's, so this goes through the same code the
    // backup sheet calls rather than through them.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 3, 10, 9));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appClockProvider.overrideWithValue(clock),
        ],
        child: const TimeLogApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimeLogApp)),
    );
    final writer = container.read(timelineWriterProvider);
    final repository = container.read(timeEntryRepositoryProvider);

    await writer.startByName(name: 'Writing');
    clock.advance(const Duration(minutes: 50));
    await writer.startByName(name: 'Email');
    clock.advance(const Duration(minutes: 20));
    await writer.stop();

    List<String> fingerprint(List<TimeEntryRow> rows) => <String>[
      for (final r in rows)
        '${r.id}|${r.activityId}|${r.startUtc}|${r.endUtc}|${r.note}',
    ];
    final before = fingerprint(await entries(db));

    final data = await repository.readForBackup();
    final file = encodeBackup(
      activities: data.activities,
      entries: data.entries,
      settings: const AppSettings(),
      exportedAt: clock.nowUtc(),
    );
    await writer.deleteAllData();
    expect(await entries(db), isEmpty);

    final read = parseBackup(file) as BackupReadOk;
    final empty = await repository.readForBackup();
    final plan = planMerge(
      incoming: read.file,
      existingEntries: empty.entries,
      existingActivities: empty.activities,
      now: clock.nowUtc(),
    );
    expect(plan.isApplicable, isTrue, reason: plan.rejection ?? '');
    await writer.applyBackup(plan);

    expect(fingerprint(await entries(db)), before);
  });
}
