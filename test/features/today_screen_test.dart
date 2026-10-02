import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/core/formatters.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
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
    testWidgets('takes two taps: the FAB, then a suggestion', (tester) async {
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
      when(
        () => h.writer.startByName(
          name: any(named: 'name'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => startOutcome());
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Writing specs'));
      await tester.pumpAndSettle();

      verify(() => h.writer.startByName(name: 'Writing specs', note: null))
          .called(1);
      expect(find.textContaining('Started Writing specs'), findsOneWidget);
    });

    testWidgets('a new name is offered as "Create ..."', (tester) async {
      final h = WidgetHarness(now: now);
      when(
        () => h.writer.startByName(
          name: any(named: 'name'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => startOutcome(name: 'Deep work'));
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Deep work');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create "Deep work"'));
      await tester.pumpAndSettle();

      verify(() => h.writer.startByName(name: 'Deep work', note: null))
          .called(1);
    });

    testWidgets('the sheet states which activity will be stopped', (
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

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
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
      when(
        () => h.writer.startByName(
          name: any(named: 'name'),
          note: any(named: 'note'),
        ),
      ).thenAnswer(
        (_) async => startOutcome(
          mode: StartMode.switched,
          name: 'Email',
          stopped: 'Writing specs',
        ),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();

      expect(find.text('Started Email, stopped Writing specs'), findsOneWidget);
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

  testWidgets('the day footer reports tracked and untracked time', (
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

    expect(find.textContaining('Tracked 2:00'), findsOneWidget);
    expect(find.textContaining('Writing specs 2:00'), findsOneWidget);
  });

  testWidgets('resuming from a day row goes through the writer', (
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

    await tester.tap(find.byTooltip('Resume Writing specs'));
    await tester.pumpAndSettle();

    verify(() => h.writer.resume('e1')).called(1);
  });
}
