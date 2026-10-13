import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:time_log/src/app/router.dart';
import 'package:time_log/src/features/shortcuts/shortcuts_sheet.dart';
import 'package:time_log/src/features/history/history_screen.dart';
import 'package:time_log/src/features/settings/settings_screen.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §8: Today / History / Settings, and how each width reaches them.
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

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
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
