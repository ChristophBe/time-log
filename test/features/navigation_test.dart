import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';
import 'package:time_log/src/app/router.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/features/entry/entry_sheet.dart';
import 'package:time_log/src/features/shortcuts/shortcuts_sheet.dart';
import 'package:time_log/src/features/history/history_screen.dart';
import 'package:time_log/src/features/projects/projects_screen.dart';
import 'package:time_log/src/features/settings/settings_screen.dart';
import 'package:time_log/src/features/today/today_providers.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §8: Today / History / Projects / Settings, and how each width reaches them.
void main() {
  final now = DateTime.utc(2026, 3, 11, 12);

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(420, 900),
  }) async {
    await WidgetHarness(now: now).pump(
      tester,
      const SizedBox.shrink(),
      surfaceSize: size,
      routerConfig: buildRouter(),
    );
  }

  testWidgets('the entry sheet opens above the shell, not inside it', (
    tester,
  ) async {
    await pumpApp(tester);

    final entry = TimeEntry(
      id: 'e1',
      activityId: 'a1',
      startUtc: now.subtract(const Duration(hours: 1)),
      endUtc: now,
      tzName: 'UTC',
    );
    unawaited(showEntrySheet(tester.element(find.byType(TodayScreen)), entry));
    await tester.pumpAndSettle();

    // Inside the shell the SnackBar is painted over the sheet, where it covers
    // Save and offers an Undo that can remove the entry on show (SPEC §6.6).
    final sheet = tester.element(find.byType(EntrySheet));
    expect(Navigator.of(sheet), Navigator.of(sheet, rootNavigator: true));
  });

  group('deep links (SPEC §8)', () {
    final entry = TimeEntry(
      id: 'e1',
      activityId: 'a1',
      startUtc: DateTime.utc(2026, 3, 8, 9),
      endUtc: DateTime.utc(2026, 3, 8, 10),
      tzName: 'UTC',
    );

    Future<WidgetHarness> pumpAt(WidgetTester tester, String location) async {
      final h = WidgetHarness(now: now);
      when(() => h.entryRepository.findEntry(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.first == entry.id ? entry : null,
      );
      await h.pump(
        tester,
        const SizedBox.shrink(),
        routerConfig: buildRouter(initialLocation: location),
      );
      // The link is acted on after the first frame.
      await tester.pumpAndSettle();
      return h;
    }

    int shownDay(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(TodayScreen)))
            .read(selectedDayProvider)
            .day;

    testWidgets('/day/:isoDate opens on that day', (tester) async {
      await pumpAt(tester, '/day/2026-03-08');
      expect(shownDay(tester), 8);
    });

    testWidgets('a malformed date falls back to today', (tester) async {
      await pumpAt(tester, '/day/not-a-date');
      expect(shownDay(tester), 11);
    });

    testWidgets('/entry/:id opens the entry sheet over its day', (
      tester,
    ) async {
      await pumpAt(tester, '/entry/e1');

      expect(find.byType(EntrySheet), findsOneWidget);
      expect(shownDay(tester), 8, reason: 'the day the entry is on');
    });

    testWidgets('an unknown entry says so and stays on today', (tester) async {
      await pumpAt(tester, '/entry/gone');

      expect(find.byType(EntrySheet), findsNothing);
      expect(find.text('That entry no longer exists'), findsOneWidget);
      expect(shownDay(tester), 11);
    });
  });

  testWidgets('a phone gets a bottom bar', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('the medium breakpoint gets a rail', (tester) async {
    await pumpApp(tester, size: const Size(800, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a desktop window gets an extended rail', (tester) async {
    await pumpApp(tester, size: const Size(1400, 900));

    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
  });

  testWidgets('each destination reaches its screen', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsScreen), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('the rail reaches Projects too', (tester) async {
    await pumpApp(tester, size: const Size(800, 900));

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Projects'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProjectsScreen), findsOneWidget);
  });

  testWidgets('a destination keeps its state across a switch', (tester) async {
    // The point of a stateful shell: coming back to a tab should not reset it.
    await pumpApp(tester);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('history-search')), 'email');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('history-search')))
          .controller!
          .text,
      'email',
    );
  });

  testWidgets('? opens the shortcut list from any destination (SPEC §10.5)', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(find.byType(ShortcutsSheet), findsOneWidget);
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
  });

  testWidgets('Ctrl+F focuses the history search (SPEC §10.5)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('history-search')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('the nav meets SPEC §10', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
