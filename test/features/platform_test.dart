import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/entry/entry_sheet.dart';
import 'package:time_log/src/features/settings/settings_screen.dart';
import 'package:time_log/src/features/today/resume_action.dart';

import '../support/pump_app.dart';

/// SPEC §9.8: the same meaning, in each platform's own idiom.
///
/// `flutter test` pins `defaultTargetPlatform` to Android, so the rest of the
/// suite is the Material path by default and these are the only tests that go
/// looking for the others.
/// Both Apple targets, because iOS and macOS share an idiom and neither should
/// be the one that was only assumed to work.
final _apple = TargetPlatformVariant(<TargetPlatform>{
  TargetPlatform.iOS,
  TargetPlatform.macOS,
});

void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final specs = activityFor(id: 'a1', name: 'Writing specs');
  final activities = <String, Activity>{specs.id: specs};
  final entry = entryFor(
    id: 'e1',
    activityId: specs.id,
    start: DateTime.utc(2026, 3, 10, 13),
    end: DateTime.utc(2026, 3, 10, 14),
  );

  Future<WidgetHarness> pumpSheet(WidgetTester tester) async {
    final h = WidgetHarness(now: now, activities: activities);
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
            child: const Text('open sheet'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    return h;
  }

  group('the time picker is the platform\'s own (SPEC §8.4)', () {
    testWidgets('a wheel on Apple', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.widgetWithText(TextButton, '14:00'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(
        find.byType(TimePickerDialog),
        findsNothing,
        reason: 'a dial is the wrong control on iOS',
      );
    }, variant: _apple);

    testWidgets('a dial on Material', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.widgetWithText(TextButton, '14:00'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);
    });

    testWidgets('cancelling the wheel changes nothing', (tester) async {
      final h = await pumpSheet(tester);
      await tester.tap(find.widgetWithText(TextButton, '14:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('14:00'), findsOneWidget);
      verifyNever(
        () => h.writer.setEntryTimes(
          entryId: any(named: 'entryId'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      );
    }, variant: _apple);
  });

  group('settings controls', () {
    testWidgets('Apple gets a Cupertino switch and sliding segments', (
      tester,
    ) async {
      await WidgetHarness(now: now).pump(tester, const SettingsScreen());

      // Several of them now: snap, the continue window, the long-run
      // threshold, the first day of the week, the day height.
      expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsWidgets);
      expect(find.byType(SegmentedButton<int>), findsNothing);
      // The switch is deliberately *not* asserted by type: Material 3 unified
      // the switch, so `Switch.adaptive` now renders one widget that takes
      // Cupertino's colour semantics on Apple rather than returning a
      // CupertinoSwitch. The adaptive constructor is still the right call --
      // there is just nothing type-shaped left to assert.
      expect(find.byType(Switch), findsOneWidget);
    }, variant: _apple);

    testWidgets('Material gets Material ones', (tester) async {
      await WidgetHarness(now: now).pump(tester, const SettingsScreen());

      expect(find.byType(SegmentedButton<int>), findsWidgets);
      expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsNothing);
    });
  });

  group('the continue-or-new choice (SPEC §6.4)', () {
    Future<void> pumpChoice(WidgetTester tester) async {
      final finished = entryFor(
        id: 'e1',
        activityId: specs.id,
        start: now.subtract(const Duration(hours: 1)),
        end: now.subtract(const Duration(minutes: 2)),
      );
      final h = WidgetHarness(
        now: now,
        activities: activities,
        lastFinished: finished,
      );
      when(() => h.writer.continueEntry(any(), window: any(named: 'window')))
          .thenAnswer((_) async => UndoToken('x', () async {}));
      await h.pump(
        tester,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => resumeOrContinue(context, ref, finished),
              child: const Text('resume'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('resume'));
      await tester.pumpAndSettle();
    }

    testWidgets('is a Cupertino alert on Apple', (tester) async {
      await pumpChoice(tester);

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.widgetWithText(CupertinoDialogAction, 'Continue'), findsOne);
    }, variant: _apple);

    testWidgets('is a Material dialog elsewhere', (tester) async {
      await pumpChoice(tester);

      // `AlertDialog.adaptive` builds a private widget rather than an
      // AlertDialog, so the Material side is asserted by what it is *not* and
      // by the button type the Material idiom uses for a default action.
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Continue'), findsOne);
    });
  });

  group('SPEC §10 holds on the Apple path too', () {
    testWidgets('settings stays labelled and hittable on iOS', (tester) async {
      final handle = tester.ensureSemantics();

      await WidgetHarness(now: now).pump(tester, const SettingsScreen());

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    }, variant: _apple);
  });
}
