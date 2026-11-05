import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/core/formatters.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/timeline_math.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §7 from the calendar: every boundary change is reachable by drag, by
/// keyboard and by screen reader, and all three go through the same writer call
/// (SPEC §10.1, §10.4, §10.5, §14.5).
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

  void stubMoves(MockTimelineWriter writer, {TimeEntry? detached}) {
    when(
      () => writer.previewBoundaryMove(
        entryId: any(named: 'entryId'),
        edge: any(named: 'edge'),
        desired: any(named: 'desired'),
        snap: any(named: 'snap'),
      ),
    ).thenAnswer((invocation) async {
      final desired =
          invocation.namedArguments[const Symbol('desired')] as DateTime;
      return BoundaryMove(
        target: entry,
        detachedNeighbour: detached,
        requested: desired,
        applied: desired,
      );
    });
    when(
      () => writer.moveBoundary(
        entryId: any(named: 'entryId'),
        edge: any(named: 'edge'),
        desired: any(named: 'desired'),
        snap: any(named: 'snap'),
        carryNeighbour: any(named: 'carryNeighbour'),
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
      // SPEC §10.4: "*Email* now ends at 15:05" — the entry, the edge, the time.
      final at = formatTimeOfDay(
        DateTime.utc(2026, 3, 10, 14, 5).toLocal(),
        use24h: true,
      );
      expect(find.text('Writing specs now ends at $at'), findsOneWidget);
    });

    testWidgets('the announcement follows the 12-hour setting', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        entries: <TimeEntry>[entry],
        dayWindows: FixedUtcDay.calculator(),
        settings: const AppSettings(use24HourClock: false),
      );
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

      final at = formatTimeOfDay(
        DateTime.utc(2026, 3, 10, 12, 55).toLocal(),
        use24h: false,
      );
      expect(find.text('Writing specs now starts at $at'), findsOneWidget);
    });

    group('a nudge away from a touching neighbour (SPEC §7.1)', () {
      final neighbour = entryFor(
        id: 'n',
        activityId: email.id,
        start: DateTime.utc(2026, 3, 10, 14),
        end: DateTime.utc(2026, 3, 10, 14, 30),
      );

      Future<WidgetHarness> nudgeEndEarlier(WidgetTester tester) async {
        final h = calendarHarness();
        stubMoves(h.writer, detached: neighbour);
        await h.pump(tester, const TodayScreen());

        final block = find.byKey(const ValueKey<String>('block-e1'));
        await tester.ensureVisible(block);
        await tester.pumpAndSettle();
        Focus.of(tester.element(block)).requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pumpAndSettle();
        return h;
      }

      testWidgets('asks, and Adjust carries the neighbour', (tester) async {
        final h = await nudgeEndEarlier(tester);

        expect(find.text('Also adjust Email?'), findsOneWidget);
        await tester.tap(find.text('Adjust Email'));
        await tester.pumpAndSettle();

        verify(
          () => h.writer.moveBoundary(
            entryId: 'e1',
            edge: BoundaryEdge.end,
            desired: DateTime.utc(2026, 3, 10, 13, 55),
            snap: const AppSettings().snap,
            carryNeighbour: true,
          ),
        ).called(1);
      });

      testWidgets('Leave gap commits without the neighbour', (tester) async {
        final h = await nudgeEndEarlier(tester);

        await tester.tap(find.text('Leave gap'));
        await tester.pumpAndSettle();

        verify(
          () => h.writer.moveBoundary(
            entryId: 'e1',
            edge: BoundaryEdge.end,
            desired: DateTime.utc(2026, 3, 10, 13, 55),
            snap: const AppSettings().snap,
          ),
        ).called(1);
      });

      testWidgets('Cancel commits nothing', (tester) async {
        final h = await nudgeEndEarlier(tester);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(
          () => h.writer.moveBoundary(
            entryId: any(named: 'entryId'),
            edge: any(named: 'edge'),
            desired: any(named: 'desired'),
            snap: any(named: 'snap'),
            carryNeighbour: any(named: 'carryNeighbour'),
          ),
        );
      });
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
}
