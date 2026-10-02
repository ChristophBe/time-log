import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §10. These are acceptance criteria, not polish: a screen that fails them
/// is not done.
void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final specs = activityFor(id: 'a1', name: 'Writing specs');
  final email = activityFor(id: 'a2', name: 'Email', colorSeed: 5);
  final activities = <String, Activity>{specs.id: specs, email.id: email};

  TimeEntry running({Duration ago = const Duration(hours: 1, minutes: 12)}) =>
      entryFor(id: 'e1', activityId: specs.id, start: now.subtract(ago));

  WidgetHarness harnessWithRunning() => WidgetHarness(
    now: now,
    activities: activities,
    running: running(),
    entries: <TimeEntry>[running()],
  );

  group('screen reader (SPEC §10.4)', () {
    testWidgets('the running card carries a coarse, on-demand label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await harnessWithRunning().pump(tester, const TodayScreen());

      expect(
        find.bySemanticsLabel(RegExp('Running: Writing specs')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('1 hour 12 minutes so far')),
        findsOneWidget,
        reason: 'minutes, not seconds -- this text is read aloud',
      );
      handle.dispose();
    });

    testWidgets('the ticking elapsed readout is not in the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await harnessWithRunning().pump(tester, const TodayScreen());

      // It is on screen...
      expect(find.text('1:12:00'), findsOneWidget);
      // ...but excluded from semantics, because a per-second live region would
      // make the screen unusable with a screen reader (SPEC §10.4).
      expect(find.bySemanticsLabel('1:12:00'), findsNothing);
      handle.dispose();
    });

    testWidgets('every tappable control is labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await harnessWithRunning().pump(tester, const TodayScreen());

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('targets and contrast (SPEC §10.2, §10.3)', () {
    testWidgets('tap targets meet the Android and iOS minimums', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await harnessWithRunning().pump(tester, const TodayScreen());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text meets the contrast guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await harnessWithRunning().pump(tester, const TodayScreen());

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('text scaling (SPEC §10.2)', () {
    for (final scale in <double>[1.0, 1.5, 2.0]) {
      testWidgets('Today renders at ${scale}x text scale', (tester) async {
        await harnessWithRunning().pump(
          tester,
          const TodayScreen(),
          textScaler: TextScaler.linear(scale),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow at ${scale}x (SPEC §10.2)',
        );
      });
    }

    testWidgets('the start sheet renders at 2x text scale', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        suggestions: <ActivitySuggestion>[
          suggestionFor(activity: specs, lastUsed: now),
          suggestionFor(activity: email, lastUsed: now),
        ],
      );
      await h.pump(
        tester,
        const TodayScreen(),
        textScaler: const TextScaler.linear(2),
      );
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('keyboard (SPEC §10.5)', () {
    testWidgets('arrow keys and Enter start a suggestion without a mouse', (
      tester,
    ) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        suggestions: <ActivitySuggestion>[
          suggestionFor(activity: specs, lastUsed: now),
          suggestionFor(activity: email, lastUsed: now),
        ],
      );
      when(
        () => h.writer.startByName(
          name: any(named: 'name'),
          note: any(named: 'note'),
        ),
      ).thenAnswer(
        (_) async => StartOutcome(
          mode: StartMode.started,
          entryId: 'new',
          activityName: 'Email',
        ),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pumpAndSettle();

      // Down twice selects the second suggestion, Enter commits it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      verify(() => h.writer.startByName(name: 'Email', note: null)).called(1);
    });

    testWidgets('Escape closes the start sheet without starting anything', (
      tester,
    ) async {
      final h = WidgetHarness(now: now, activities: activities);
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('What are you doing?'), findsNothing);
      verifyNever(
        () => h.writer.startByName(
          name: any(named: 'name'),
          note: any(named: 'note'),
        ),
      );
    });
  });
}
