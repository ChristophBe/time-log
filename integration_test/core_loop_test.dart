import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_log/src/app/app.dart';
import 'package:time_log/src/core/clock.dart';
import 'package:time_log/src/data/db/database.dart';
import 'package:time_log/src/data/db/database_provider.dart';

/// SPEC §12's integration suite: the core loop on real SQLite, on a real
/// device. Run it with:
///
///     flutter test integration_test -d <device>
///
/// The database is in memory on purpose. This builds with the app's own bundle
/// id, so `AppDatabase.open()` here would be the developer's real timeline.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('start, switch, and the running entry survives a rebuild', (
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
    // and left up it would take the tap: it sits over the Start button.
    clock.advance(const Duration(minutes: 5));
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

    // History has both of them.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Writing'), findsOneWidget);

    // And the running one is still running after a full rebuild, because a
    // running entry is nothing but a stored startUtc (SPEC §9.1).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('since'), findsOneWidget);
  });
}
