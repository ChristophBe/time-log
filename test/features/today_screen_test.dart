import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/core/formatters.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/today/action_feedback.dart';
import 'package:time_log/src/features/today/day_header.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final specs = activityFor(id: 'a1', name: 'Writing specs', colorSeed: 0);
  final email = activityFor(id: 'a2', name: 'Email', colorSeed: 1);
  final activities = <String, Activity>{specs.id: specs, email.id: email};

  StartOutcome startOutcome({
    StartMode mode = StartMode.started,
    String name = 'Writing specs',
    String? stopped,
  }) => StartOutcome(
    mode: mode,
    entryId: 'new',
    activityName: name,
    stoppedActivityName: stopped,
  );

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  testWidgets('idle state says nothing is running', (tester) async {
    final h = WidgetHarness(now: now);
    await h.pump(tester, const TodayScreen());

    expect(find.text('Nothing is running'), findsOneWidget);
    expect(find.text('No entries for this day'), findsOneWidget);
  });

  testWidgets('idle state offers to resume the last activity', (tester) async {
    final last = entryFor(
      id: 'e1',
      activityId: specs.id,
      start: now.subtract(const Duration(hours: 2)),
      end: now.subtract(const Duration(hours: 1)),
    );
    final h = WidgetHarness(
      now: now,
      activities: activities,
      entries: <TimeEntry>[last],
      lastFinished: last,
    );
    await h.pump(tester, const TodayScreen());

    expect(find.text('Resume Writing specs'), findsOneWidget);
  });

  testWidgets('the running card shows the activity, start time and elapsed', (
    tester,
  ) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      running: entryFor(
        id: 'e1',
        activityId: specs.id,
        start: now.subtract(const Duration(hours: 1, minutes: 12)),
        note: 'chapter 3',
      ),
    );
    await h.pump(tester, const TodayScreen());

    expect(find.text('Writing specs'), findsWidgets);
    expect(find.text('chapter 3'), findsOneWidget);
    expect(find.textContaining('since'), findsOneWidget);
    expect(
      find.text('1:12:00'),
      findsOneWidget,
      reason: 'H:MM:SS over an hour',
    );
    expect(find.widgetWithText(FilledButton, 'Stop'), findsOneWidget);
  });

  testWidgets('a clock jump shows an explanation, never a negative duration', (
    tester,
  ) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      running: entryFor(
        id: 'e1',
        activityId: specs.id,
        start: now.add(const Duration(hours: 2)),
      ),
    );
    await h.pump(tester, const TodayScreen());

    expect(find.text('This entry started in the future'), findsOneWidget);
    expect(find.text('Fix start time'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'-\d')),
      findsNothing,
      reason: 'SPEC §9.2: no negative duration is ever rendered',
    );
  });

  group('starting', () {
    testWidgets('the composer is on screen with no FAB in front of it', (
      tester,
    ) async {
      final h = WidgetHarness(now: now, activities: activities);
      await h.pump(tester, const TodayScreen());

      expect(
        find.byType(FloatingActionButton),
        findsNothing,
        reason: 'SPEC §8.1: the start control is the composer, not a FAB',
      );
      expect(find.byKey(const Key('start-field')), findsOneWidget);
      expect(find.byKey(const Key('start-button')), findsOneWidget);
    });

    testWidgets('rests closed: no suggestions until the field is used', (
      tester,
    ) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        suggestions: <ActivitySuggestion>[suggestionFor(activity: specs)],
      );
      await h.pump(tester, const TodayScreen());

      expect(
        find.text('Writing specs'),
        findsNothing,
        reason: 'SPEC §8.1: the day keeps the screen until the field is used',
      );
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason: 'SPEC §8.3: no keyboard on launch',
      );

      await tester.tap(find.byKey(const Key('start-field')));
      await tester.pumpAndSettle();

      expect(find.text('Writing specs'), findsOneWidget);
    });

    testWidgets('the no-history hint gives way once a name is typed', (
      tester,
    ) async {
      final h = WidgetHarness(now: now);
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.byKey(const Key('start-field')));
      await tester.pumpAndSettle();
      expect(
        find.text('Type what you are doing to start tracking it.'),
        findsOneWidget,
        reason: 'SPEC §9.6: an empty panel on a fresh install looks broken',
      );

      await tester.enterText(find.byKey(const Key('start-field')), 'Deep work');
      await tester.pumpAndSettle();

      expect(
        find.text('Type what you are doing to start tracking it.'),
        findsNothing,
        reason: 'it must not tell the user to do what they are already doing',
      );
    });

    testWidgets('one tap on a suggestion starts it', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        suggestions: <ActivitySuggestion>[
          suggestionFor(
            activity: specs,
            lastUsed: now.subtract(const Duration(hours: 2)),
          ),
          suggestionFor(
            activity: email,
            lastUsed: now.subtract(const Duration(days: 1)),
          ),
        ],
      );
      when(() => h.writer.startByName(name: any(named: 'name')))
          .thenAnswer((_) async => startOutcome());
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.byKey(const Key('start-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Writing specs'));
      await tester.pumpAndSettle();

      verify(() => h.writer.startByName(name: 'Writing specs')).called(1);
      expect(find.textContaining('Started Writing specs'), findsOneWidget);
    });

    testWidgets('a typed name that matches nothing is created by Start', (
      tester,
    ) async {
      final h = WidgetHarness(now: now);
      when(() => h.writer.startByName(name: any(named: 'name')))
          .thenAnswer((_) async => startOutcome(name: 'Deep work'));
      await h.pump(tester, const TodayScreen());

      await tester.enterText(find.byKey(const Key('start-field')), 'Deep work');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-button')));
      await tester.pumpAndSettle();

      verify(() => h.writer.startByName(name: 'Deep work')).called(1);
    });

    testWidgets('Start is disabled until the field holds a usable name', (
      tester,
    ) async {
      final h = WidgetHarness(now: now);
      await h.pump(tester, const TodayScreen());

      FilledButton button() =>
          tester.widget<FilledButton>(find.byKey(const Key('start-button')));
      expect(button().onPressed, isNull);

      await tester.enterText(find.byKey(const Key('start-field')), '   ');
      await tester.pumpAndSettle();
      expect(
        button().onPressed,
        isNull,
        reason: 'whitespace is not a name (SPEC §5.1)',
      );

      await tester.enterText(find.byKey(const Key('start-field')), 'Email');
      await tester.pumpAndSettle();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('the field clears and lets go after a start', (tester) async {
      final h = WidgetHarness(now: now);
      when(() => h.writer.startByName(name: any(named: 'name')))
          .thenAnswer((_) async => startOutcome(name: 'Deep work'));
      await h.pump(tester, const TodayScreen());

      await tester.enterText(find.byKey(const Key('start-field')), 'Deep work');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-button')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('start-field')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        find.text('Deep work'),
        findsNothing,
        reason: 'the composer returns to rest so the day is visible again',
      );
    });

    testWidgets('the composer states which activity will be stopped', (
      tester,
    ) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        running: entryFor(
          id: 'e1',
          activityId: specs.id,
          start: now.subtract(const Duration(minutes: 30)),
        ),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.byKey(const Key('start-field')));
      await tester.pumpAndSettle();

      final expectedTime = formatTimeOfDay(now.toLocal(), use24h: true);
      expect(
        find.text('Stops Writing specs at $expectedTime.'),
        findsOneWidget,
        reason: 'SPEC §8.3: state the consequence before committing',
      );
    });

    testWidgets('a switch reports both activities', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        running: entryFor(
          id: 'e1',
          activityId: specs.id,
          start: now.subtract(const Duration(minutes: 30)),
        ),
        suggestions: <ActivitySuggestion>[suggestionFor(activity: email)],
      );
      when(() => h.writer.startByName(name: any(named: 'name'))).thenAnswer(
        (_) async => startOutcome(
          mode: StartMode.switched,
          name: 'Email',
          stopped: 'Writing specs',
        ),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.byKey(const Key('start-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();

      expect(find.text('Started Email, stopped Writing specs'), findsOneWidget);
    });

    testWidgets('Cmd/Ctrl+N focuses the field (SPEC §10.5)', (tester) async {
      final h = WidgetHarness(now: now);
      await h.pump(tester, const TodayScreen());

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('start-field')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('the day keys belong to the field while it has focus', (
      tester,
    ) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: FixedUtcDay.calculator(),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.byKey(const Key('start-field')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();

      expect(
        // "Today" is the whole answer to "which day is this", and it is the
        // only form that never ellipsises beside four buttons and the total.
        // The full date stays in the picker and in the spoken label.
        find.text('Today'),
        findsOneWidget,
        reason:
            'SPEC §10.5: the arrows move the caret and "t" types, so neither '
            'may reach the day navigation',
      );

      // ...and the day keys come back the moment the field lets go.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // The year is dropped in the current year.
      expect(find.text('Mon, Mar 9'), findsOneWidget);
    });

    testWidgets('Escape abandons what was typed without starting', (
      tester,
    ) async {
      final h = WidgetHarness(now: now);
      await h.pump(tester, const TodayScreen());

      await tester.enterText(find.byKey(const Key('start-field')), 'Oops');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('start-field')))
            .controller!
            .text,
        isEmpty,
      );
      verifyNever(() => h.writer.startByName(name: any(named: 'name')));
    });

    testWidgets('the undo snackbar never covers the field', (tester) async {
      final h = WidgetHarness(now: now);
      when(() => h.writer.startByName(name: any(named: 'name')))
          .thenAnswer((_) async => startOutcome(name: 'Deep work'));
      await h.pump(tester, const TodayScreen());

      await tester.enterText(find.byKey(const Key('start-field')), 'Deep work');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      final field = tester.getRect(find.byKey(const Key('start-field')));
      final snack = tester.getRect(find.byType(SnackBar));
      expect(
        snack.bottom,
        lessThanOrEqualTo(field.top),
        reason:
            'the theme floats SnackBars, so an 8-second Undo must not sit on '
            'the one control that is always meant to be reachable',
      );
    });
  });

  group('stopping', () {
    testWidgets('offers Undo', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        running: entryFor(
          id: 'e1',
          activityId: specs.id,
          start: now.subtract(const Duration(minutes: 30)),
        ),
      );
      when(() => h.writer.stop()).thenAnswer(
        (_) async => StopOutcome(
          stopped: true,
          entryId: 'e1',
          activityName: 'Writing specs',
          duration: const Duration(minutes: 30),
          undo: UndoToken('x', () async {}),
        ),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stopped Writing specs'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('the Undo bar goes away on its own', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        running: entryFor(
          id: 'e1',
          activityId: specs.id,
          start: now.subtract(const Duration(minutes: 30)),
        ),
      );
      when(() => h.writer.stop()).thenAnswer(
        (_) async => StopOutcome(
          stopped: true,
          entryId: 'e1',
          activityName: 'Writing specs',
          duration: const Duration(minutes: 30),
          undo: UndoToken('x', () async {}),
        ),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pump(kUndoWindow);
      await tester.pumpAndSettle();

      expect(
        find.byType(SnackBar),
        findsNothing,
        reason:
            'the undo window is eight seconds, and the bar sits over the start '
            'composer (SPEC §7.5, §8.1). SnackBar.persist defaults to '
            '`action != null`, so this only holds because it is set.',
      );
    });

    testWidgets('a sub-minute stop offers Discard instead', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        running: entryFor(
          id: 'e1',
          activityId: specs.id,
          start: now.subtract(const Duration(seconds: 20)),
        ),
      );
      when(() => h.writer.stop()).thenAnswer(
        (_) async => StopOutcome(
          stopped: true,
          entryId: 'e1',
          activityName: 'Oops',
          duration: const Duration(seconds: 20),
          undo: UndoToken('x', () async {}),
        ),
      );
      when(() => h.writer.delete(any()))
          .thenAnswer((_) async => UndoToken('x', () async {}));
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
      await tester.pumpAndSettle();

      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });
  });

  testWidgets('the day header reports the tracked total next to the date', (
    tester,
  ) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      entries: <TimeEntry>[
        entryFor(
          id: 'e1',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 10, 9),
          end: DateTime.utc(2026, 3, 10, 11),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());

    expect(find.text('2 h'), findsOneWidget);
    expect(
      // Gaps on the calendar say "untracked" on themselves; what this guards
      // is that the *header* carries the tracked total and nothing else
      // (SPEC §8.1, §16.5).
      find.descendant(
        of: find.byType(DayHeader),
        matching: find.textContaining('untracked'),
      ),
      findsNothing,
      reason: 'the header carries the one number worth reading at a glance',
    );
    expect(find.textContaining('Writing specs 2:00'), findsNothing);
  });

  testWidgets('resuming from a calendar block goes through the writer', (
    tester,
  ) async {
    final entry = entryFor(
      id: 'e1',
      activityId: specs.id,
      start: now.subtract(const Duration(hours: 3)),
      end: now.subtract(const Duration(hours: 2)),
    );
    final h = WidgetHarness(
      now: now,
      activities: activities,
      entries: <TimeEntry>[entry],
      lastFinished: entry,
    );
    when(() => h.writer.resume(any())).thenAnswer((_) async => startOutcome());
    await h.pump(tester, const TodayScreen());

    // The calendar opens scrolled to the now-line, so this block sits above the
    // viewport until we scroll to it.
    final block = find.byKey(const ValueKey<String>('block-e1'));
    await tester.ensureVisible(block);
    await tester.pumpAndSettle();
    await tester.tap(block);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Resume'));
    await tester.pumpAndSettle();

    verify(() => h.writer.resume('e1')).called(1);
  });
}
