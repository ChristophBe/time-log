import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/timeline_math.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/entry/entry_providers.dart';
import 'package:time_log/src/features/entry/entry_sheet.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §7 and §8.4 as they appear in the UI: every boundary change is reachable
/// by drag, by typing and by keyboard, and all three go through the same writer
/// call (SPEC §10.1, §14.5).
void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final specs = activityFor(id: 'a1', name: 'Writing specs');
  final email = activityFor(id: 'a2', name: 'Email', colorSeed: 3);
  final activities = <String, Activity>{specs.id: specs, email.id: email};

  // 13:00 to 14:00 UTC, an hour before now.
  final entry = entryFor(
    id: 'e1',
    activityId: specs.id,
    start: DateTime.utc(2026, 3, 10, 13),
    end: DateTime.utc(2026, 3, 10, 14),
  );

  setUpAll(() {
    registerFallbackValue(BoundaryEdge.start);
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(Duration.zero);
  });

  void stubMoves(MockTimelineWriter writer) {
    when(
      () => writer.moveBoundary(
        entryId: any(named: 'entryId'),
        edge: any(named: 'edge'),
        desired: any(named: 'desired'),
        snap: any(named: 'snap'),
      ),
    ).thenAnswer(
      (invocation) async => MoveOutcome(
        wasClamped: false,
        appliedUtc:
            invocation.namedArguments[const Symbol('desired')] as DateTime,
        undo: UndoToken('x', () async {}),
      ),
    );
  }

  WidgetHarness calendarHarness() => WidgetHarness(
    now: now,
    activities: activities,
    entries: <TimeEntry>[entry],
    dayWindows: FixedUtcDay.calculator(),
  );

  group('keyboard editing (SPEC §10.5)', () {
    testWidgets('Shift+Down moves the end one snap later', (tester) async {
      final h = calendarHarness();
      stubMoves(h.writer);
      await h.pump(tester, const TodayScreen());

      final block = find.byKey(const ValueKey<String>('block-e1'));
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();
      // Focus the block the way Tab would. Tapping it would open the sheet, and
      // the keys would go there instead.
      Focus.of(tester.element(block)).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();

      verify(
        () => h.writer.moveBoundary(
          entryId: 'e1',
          edge: BoundaryEdge.end,
          desired: DateTime.utc(2026, 3, 10, 14, 5),
          snap: const AppSettings().snap,
        ),
      ).called(1);
    });

    testWidgets('Alt+Up moves the start one snap earlier', (tester) async {
      final h = calendarHarness();
      stubMoves(h.writer);
      await h.pump(tester, const TodayScreen());

      final block = find.byKey(const ValueKey<String>('block-e1'));
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();
      Focus.of(tester.element(block)).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();

      verify(
        () => h.writer.moveBoundary(
          entryId: 'e1',
          edge: BoundaryEdge.start,
          desired: DateTime.utc(2026, 3, 10, 12, 55),
          snap: const AppSettings().snap,
        ),
      ).called(1);
    });
  });

  group('screen reader editing (SPEC §10.4)', () {
    testWidgets('the increase action lengthens the entry by one snap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = calendarHarness();
      stubMoves(h.writer);
      await h.pump(tester, const TodayScreen());

      final block = find.byKey(const ValueKey<String>('block-e1'));
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();
      tester.semantics.performAction(
        find.semantics.byValue('1 hour'),
        SemanticsAction.increase,
      );
      await tester.pumpAndSettle();

      verify(
        () => h.writer.moveBoundary(
          entryId: 'e1',
          edge: BoundaryEdge.end,
          desired: DateTime.utc(2026, 3, 10, 14, 5),
          snap: const AppSettings().snap,
        ),
      ).called(1);
      handle.dispose();
    });

    testWidgets('the block announces its duration as its value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = calendarHarness();
      await h.pump(tester, const TodayScreen());

      final block = find.byKey(const ValueKey<String>('block-e1'));
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();
      final semantics = tester.getSemantics(block);

      expect(semantics.value, '1 hour');
      expect(semantics.increasedValue, '1 hour 5 minutes');
      expect(semantics.decreasedValue, '55 minutes');
      handle.dispose();
    });
  });

  group('drag editing (SPEC §7)', () {
    testWidgets('long press on the bottom half then drag moves the end', (
      tester,
    ) async {
      final h = calendarHarness();
      stubMoves(h.writer);
      await h.pump(tester, const TodayScreen());

      final block = find.byKey(const ValueKey<String>('block-e1'));
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();

      final box = tester.getRect(block);
      // Bottom half of the block grabs the end boundary.
      final gesture = await tester.startGesture(
        Offset(box.center.dx, box.bottom - 8),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // 72 px per hour by default, so 36 px is half an hour.
      await gesture.moveBy(const Offset(0, 36));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final captured = verify(
        () => h.writer.moveBoundary(
          entryId: 'e1',
          edge: captureAny(named: 'edge'),
          desired: captureAny(named: 'desired'),
          snap: any(named: 'snap'),
        ),
      ).captured;
      expect(captured.first, BoundaryEdge.end);
      expect(
        captured[1],
        DateTime.utc(2026, 3, 10, 14, 30),
        reason:
            '36 px at 72 px/hour is half an hour, measured from the '
            'boundary rather than from wherever the finger landed',
      );
    });

    testWidgets('a drag shows a live readout of the time it would land on', (
      tester,
    ) async {
      final h = calendarHarness();
      stubMoves(h.writer);
      await h.pump(tester, const TodayScreen());

      final block = find.byKey(const ValueKey<String>('block-e1'));
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();

      final box = tester.getRect(block);
      final gesture = await tester.startGesture(
        Offset(box.center.dx, box.bottom - 8),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 36));
      await tester.pump();

      expect(find.text('15:30'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the running entry cannot be dragged by its end', (
      tester,
    ) async {
      final running = entryFor(
        id: 'r1',
        activityId: specs.id,
        start: DateTime.utc(2026, 3, 10, 13),
      );
      final h = WidgetHarness(
        now: now,
        activities: activities,
        entries: <TimeEntry>[running],
        running: running,
        dayWindows: FixedUtcDay.calculator(),
      );
      stubMoves(h.writer);
      await h.pump(tester, const TodayScreen());

      final block = find.byKey(const ValueKey<String>('block-r1'));
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();

      final box = tester.getRect(block);
      final gesture = await tester.startGesture(
        Offset(box.center.dx, box.bottom - 8),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 36));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      verifyNever(
        () => h.writer.moveBoundary(
          entryId: any(named: 'entryId'),
          edge: BoundaryEdge.end,
          desired: any(named: 'desired'),
          snap: any(named: 'snap'),
        ),
      );
    });
  });

  group('entry sheet (SPEC §8.4)', () {
    Future<WidgetHarness> pumpSheet(
      WidgetTester tester, {
      TimeEntry? target,
      EntryNeighbours neighbours = const (previous: null, next: null),
    }) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        entries: <TimeEntry>[target ?? entry],
        neighbours: neighbours,
      );
      when(
        () => h.writer.setEntryTimes(
          entryId: any(named: 'entryId'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => UndoToken('x', () async {}));
      when(() => h.writer.delete(any()))
          .thenAnswer((_) async => UndoToken('x', () async {}));
      when(
        () => h.writer.split(
          entryId: any(named: 'entryId'),
          atUtc: any(named: 'atUtc'),
        ),
      ).thenAnswer((_) async => UndoToken('x', () async {}));
      await h.pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEntrySheet(context, target ?? entry),
              child: const Text('open sheet'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('shows start, end and duration', (tester) async {
      await pumpSheet(tester);

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
    });

    testWidgets('the end stepper changes the end and the duration together', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.tap(find.byTooltip('End 5 minutes later'));
      await tester.pumpAndSettle();

      expect(find.text('15:05'), findsOneWidget);
      expect(find.text('1:05'), findsOneWidget, reason: 'SPEC §8.4');
    });

    testWidgets('the duration stepper moves the end, not the start', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.tap(find.byTooltip('Duration 5 minutes later'));
      await tester.pumpAndSettle();

      expect(find.text('14:00'), findsOneWidget, reason: 'start unchanged');
      expect(find.text('15:05'), findsOneWidget);
    });

    testWidgets('Save is disabled until something changes', (tester) async {
      await pumpSheet(tester);

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('End 5 minutes later'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('Save writes the typed times through the writer', (
      tester,
    ) async {
      final h = await pumpSheet(tester);

      await tester.tap(find.byTooltip('End 5 minutes later'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      verify(
        () => h.writer.setEntryTimes(
          entryId: 'e1',
          startUtc: DateTime.utc(2026, 3, 10, 13),
          endUtc: DateTime.utc(2026, 3, 10, 14, 5),
        ),
      ).called(1);
    });

    testWidgets('an overlap across a gap is named inline and blocks Save', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        neighbours: (
          // Ends at 13:30, with a gap before our 14:00 start -- so moving the
          // start back to 13:25 is a genuine overlap, not a shared boundary.
          previous: entryFor(
            id: 'p',
            activityId: email.id,
            start: DateTime.utc(2026, 3, 10, 12),
            end: DateTime.utc(2026, 3, 10, 12, 30),
          ),
          next: null,
        ),
      );

      // Walk the start back past 12:30.
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byTooltip('Start 5 minutes earlier'));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const Key('entry-sheet-conflict')), findsOneWidget);
      expect(find.textContaining('Overlaps Email until'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
        reason: 'SPEC §7.2: a typed conflict is reported, not silently clamped',
      );
    });

    testWidgets('Delete removes the entry and offers Undo', (tester) async {
      final h = await pumpSheet(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      verify(() => h.writer.delete('e1')).called(1);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('Split cuts the entry at its midpoint', (tester) async {
      final h = await pumpSheet(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Split in half'));
      await tester.pumpAndSettle();

      verify(
        () => h.writer.split(
          entryId: 'e1',
          atUtc: DateTime.utc(2026, 3, 10, 13, 30),
        ),
      ).called(1);
    });

    testWidgets('the running entry shows no end field and cannot be split', (
      tester,
    ) async {
      final running = entryFor(
        id: 'r1',
        activityId: specs.id,
        start: DateTime.utc(2026, 3, 10, 13),
      );
      await pumpSheet(tester, target: running);

      expect(find.text('running'), findsOneWidget);
      expect(find.byTooltip('End 5 minutes later'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'Split in half'),
        findsNothing,
      );
      expect(find.widgetWithText(OutlinedButton, 'Resume'), findsNothing);
    });

    testWidgets('renders at 2x text scale without overflow', (tester) async {
      final h = WidgetHarness(now: now, activities: activities);
      await h.pump(
        tester,
        Scaffold(body: EntrySheet(entry: entry)),
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
