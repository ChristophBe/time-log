import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/core/clock.dart';
import 'package:time_log/src/core/formatters.dart';
import 'package:time_log/src/core/ids.dart';
import 'package:time_log/src/core/time_zone.dart';
import 'package:time_log/src/data/db/database.dart';
import 'package:time_log/src/data/repositories/active_session_repository.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/presence/active_session.dart';
import 'package:time_log/src/domain/presence/presence_rules.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/calendar/day_navigation_bar.dart';
import 'package:time_log/src/features/presence/active_rail.dart';
import 'package:time_log/src/features/presence/presence_controller.dart';
import 'package:time_log/src/features/presence/presence_port.dart';
import 'package:time_log/src/features/settings/settings_screen.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

class FakePresencePort implements PresencePort {
  final signalsController = StreamController<PresenceSignal>.broadcast();
  PresenceSignal? state;
  final calls = <({bool enabled, bool updateLoginItem})>[];

  @override
  bool get isSupported => true;

  @override
  Stream<PresenceSignal> get signals => signalsController.stream;

  @override
  Future<PresenceSignal> currentState() async => state!;

  @override
  Future<void> setTracking({
    required bool enabled,
    required bool updateLoginItem,
  }) async => calls.add((enabled: enabled, updateLoginItem: updateLoginItem));

  @override
  Future<LoginItemStatus> loginItemStatus() async =>
      LoginItemStatus.requiresApproval;

  @override
  Future<void> openLoginItemSettings() async {}
}

/// SPEC §8.1, §8.2, §8.6, §9.9.
void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final sessionStart = DateTime.utc(2026, 3, 10, 8);
  final sessionEnd = DateTime.utc(2026, 3, 10, 12);

  setUpAll(() {
    registerFallbackValue(const AppSettings());
    registerFallbackValue(DateTime.utc(2026));
  });

  WidgetHarness withSession() => WidgetHarness(
    now: now,
    dayWindows: FixedUtcDay.calculator(),
    sessions: <ActiveSession>[
      sessionFor(id: 's1', start: sessionStart, end: sessionEnd),
    ],
  );

  group('the rail', () {
    testWidgets('is not there on a day without sessions', (tester) async {
      await WidgetHarness(now: now).pump(tester, const TodayScreen());

      expect(find.textContaining('Active'), findsNothing);
      expect(find.byKey(const ValueKey('active-rail-s1')), findsNothing);
    });

    testWidgets('spans the session and is labelled', (tester) async {
      await withSession().pump(tester, const TodayScreen());

      final rail = find.byKey(const ValueKey('active-rail-s1'));
      expect(rail, findsOneWidget);
      expect(tester.getSize(rail).height, 72.0 * 4);
      expect(
        find.bySemanticsLabel(
          'At the computer, ${_local(sessionStart)} to ${_local(sessionEnd)}, '
          '4 hours',
        ),
        findsOneWidget,
      );
    });

    testWidgets('still shows on a day with no entries', (tester) async {
      await withSession().pump(tester, const TodayScreen());

      expect(find.text('No entries for this day'), findsNothing);
      expect(find.byType(ActiveRail), findsOneWidget);
    });

    testWidgets('takes no input', (tester) async {
      await withSession().pump(tester, const TodayScreen());

      expect(
        find.descendant(
          of: find.byType(ActiveRail),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });
  });

  group('logging active time', () {
    testWidgets('the total opens the unlogged spans', (tester) async {
      final harness = withSession();
      await harness.pump(tester, const Scaffold(body: DayNavigationRow()));

      await tester.tap(find.bySemanticsLabel('Active 4 hours'));
      await tester.pumpAndSettle();

      expect(find.text('Unlogged active time'), findsOneWidget);
      expect(find.textContaining('–'), findsOneWidget);
    });

    testWidgets('the total is a legal target at 1x and 2x', (tester) async {
      for (final scale in <double>[1, 2]) {
        await withSession().pump(
          tester,
          const Scaffold(body: DayNavigationRow()),
          textScaler: TextScaler.linear(scale),
        );
        final target = tester.getSize(find.byKey(const Key('active-total')));
        expect(target.height, greaterThanOrEqualTo(48), reason: '$scale×');
      }
    });

    testWidgets('picking a span adds an entry for exactly it', (tester) async {
      final harness = withSession();
      when(
        () => harness.writer.insertEntry(
          name: any(named: 'name'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => UndoToken('Added', () async {}));
      await harness.pump(tester, const Scaffold(body: DayNavigationRow()));

      await tester.tap(find.bySemanticsLabel('Active 4 hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('activity-name-field')),
        'Email',
      );
      await tester.pump();
      await tester.tap(find.text('Add entry'));
      await tester.pumpAndSettle();

      verify(
        () => harness.writer.insertEntry(
          name: 'Email',
          startUtc: sessionStart,
          endUtc: sessionEnd,
        ),
      ).called(1);
    });

    testWidgets('a covered day says so and offers nothing', (tester) async {
      final harness = WidgetHarness(
        now: now,
        dayWindows: FixedUtcDay.calculator(),
        sessions: <ActiveSession>[
          sessionFor(id: 's1', start: sessionStart, end: sessionEnd),
        ],
        entries: <TimeEntry>[
          entryFor(
            id: 'e1',
            activityId: 'a1',
            start: sessionStart,
            end: sessionEnd,
          ),
        ],
      );
      await harness.pump(tester, const Scaffold(body: DayNavigationRow()));

      await tester.tap(find.bySemanticsLabel('Active 4 hours'));
      await tester.pumpAndSettle();

      expect(find.textContaining('already logged'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('off a supported platform the switch says so', (tester) async {
      await WidgetHarness(now: now).pump(
        tester,
        const SettingsScreen(),
        surfaceSize: const Size(420, 2400),
      );

      expect(find.text('Only available on macOS for now.'), findsOneWidget);
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Track time at this computer'),
      );
      expect(tile.onChanged, isNull);
    });
  });

  group('the controller', () {
    late AppDatabase db;
    late FakeClock clock;
    late FakePresencePort port;
    late ActiveSessionRepository sessions;
    late PresenceController controller;
    final t0 = DateTime.utc(2026, 3, 10, 9);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      clock = FakeClock(t0);
      port = FakePresencePort()..state = PresenceSignal.active(t0);
      sessions = ActiveSessionRepository(
        db: db,
        clock: clock,
        ids: SequentialIdGenerator('s'),
        timeZone: const FixedTimeZoneResolver('Europe/Berlin'),
      );
      controller = PresenceController(port: port, sessions: () => sessions);
    });
    tearDown(() async {
      await controller.dispose();
      await db.close();
    });

    test('off at launch does nothing at all', () async {
      controller.sync(enabled: false);
      await controller.settled;

      expect(port.calls, isEmpty);
      expect(await sessions.open(), isNull);
    });

    test('on at launch records, and leaves the login item alone', () async {
      controller.sync(enabled: true);
      await controller.settled;

      expect(port.calls.single, (enabled: true, updateLoginItem: false));
      expect(await sessions.open(), isNotNull);
    });

    test('flipping the switch touches the login item', () async {
      controller.sync(enabled: false);
      controller.sync(enabled: true);
      await controller.settled;
      expect(port.calls.single, (enabled: true, updateLoginItem: true));

      clock.advance(const Duration(minutes: 1));
      controller.sync(enabled: false);
      await controller.settled;
      expect(port.calls.last, (enabled: false, updateLoginItem: true));
      expect(await sessions.open(), isNull);
    });

    test('a signal reaches the repository', () async {
      controller.sync(enabled: true);
      await controller.settled;

      port.signalsController.add(
        PresenceSignal.inactive(
          SessionEndReason.lock,
          t0.add(const Duration(minutes: 5)),
        ),
      );
      await pumpEventQueue();
      await db.select(db.activeSessions).get();

      expect(await sessions.open(), isNull);
    });

    test('a beat catches a lock no notification reported', () async {
      controller.sync(enabled: true);
      await controller.settled;

      clock.advance(const Duration(minutes: 1));
      port.state = PresenceSignal.inactive(
        SessionEndReason.lock,
        clock.nowUtc(),
      );
      await controller.beat();

      expect(await sessions.open(), isNull);
    });

    test('a failing platform does not take the app down', () async {
      port.state = null;
      controller.sync(enabled: true);
      await expectLater(controller.settled, completes);
    });
  });
}

String _local(DateTime utc) => formatTimeOfDay(utc.toLocal(), use24h: true);
