import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/calendar/entry_block.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §8.2's gap filling and short-entry clustering, and §8.1's long-run
/// banner.
void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  const specs = Activity(id: 'a1', name: 'Writing specs', colorSeed: 0);
  const activities = <String, Activity>{'a1': specs};

  DayWindowCalculator utcDays() => FixedDayWindowCalculator(<DayWindow>[
    DayWindow(
      startUtc: DateTime.utc(2026, 3, 9),
      endUtc: DateTime.utc(2026, 3, 10),
      year: 2026,
      month: 3,
      day: 9,
    ),
    DayWindow(
      startUtc: DateTime.utc(2026, 3, 10),
      endUtc: DateTime.utc(2026, 3, 11),
      year: 2026,
      month: 3,
      day: 10,
    ),
  ]);

  TimeEntry entry({
    required String id,
    required DateTime start,
    DateTime? end,
  }) => TimeEntry(
    id: id,
    activityId: 'a1',
    startUtc: start,
    endUtc: end,
    tzName: 'Europe/Berlin',
  );

  group('filling a gap (SPEC §8.2)', () {
    Future<WidgetHarness> pumpWithGap(WidgetTester tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
        entries: <TimeEntry>[
          entry(
            id: 'e1',
            start: DateTime.utc(2026, 3, 10, 11),
            end: DateTime.utc(2026, 3, 10, 12),
          ),
          entry(
            id: 'e2',
            start: DateTime.utc(2026, 3, 10, 13),
            end: DateTime.utc(2026, 3, 10, 14),
          ),
        ],
      );
      when(
        () => h.writer.insertEntry(
          name: any(named: 'name'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => UndoToken('x', () async {}));
      await h.pump(tester, const TodayScreen());
      return h;
    }

    testWidgets('tapping a gap creates an entry covering exactly it', (
      tester,
    ) async {
      final h = await pumpWithGap(tester);

      // The hour between the two entries, which is 72px tall and so hittable.
      // Found by its own label rather than by a clock time, which depends on
      // the zone the test is running in.
      // The calendar opens scrolled to now, so the gap has to be brought into
      // view before it can be tapped.
      await tester.ensureVisible(find.text('1 h untracked'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 h untracked'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('fill-gap-name')), 'Lunch');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add entry'));
      await tester.pumpAndSettle();

      verify(
        () => h.writer.insertEntry(
          name: 'Lunch',
          startUtc: DateTime.utc(2026, 3, 10, 12),
          endUtc: DateTime.utc(2026, 3, 10, 13),
        ),
      ).called(1);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('an unnamed entry cannot be added', (tester) async {
      await pumpWithGap(tester);

      await tester.ensureVisible(find.text('1 h untracked'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 h untracked'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add entry'),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('short entries (SPEC §8.2)', () {
    testWidgets('several that would collide become one chip', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
        entries: <TimeEntry>[
          for (var i = 0; i < 3; i++)
            entry(
              id: 'short$i',
              start: DateTime.utc(
                2026,
                3,
                10,
                12,
              ).add(Duration(minutes: i * 2)),
              end: DateTime.utc(
                2026,
                3,
                10,
                12,
              ).add(Duration(minutes: i * 2 + 2)),
            ),
        ],
      );
      await h.pump(tester, const TodayScreen());

      expect(find.text('3 short entries'), findsOneWidget);
      expect(
        find.byType(EntryBlock),
        findsNothing,
        reason: 'stood in for by the chip until it is opened',
      );
    });

    testWidgets('tapping the chip shows them individually', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
        entries: <TimeEntry>[
          for (var i = 0; i < 3; i++)
            entry(
              id: 'short$i',
              start: DateTime.utc(
                2026,
                3,
                10,
                12,
              ).add(Duration(minutes: i * 2)),
              end: DateTime.utc(
                2026,
                3,
                10,
                12,
              ).add(Duration(minutes: i * 2 + 2)),
            ),
        ],
      );
      await h.pump(tester, const TodayScreen());

      await tester.ensureVisible(find.text('3 short entries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 short entries'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('3 short entries'), findsNothing);
      expect(find.byType(EntryBlock), findsNWidgets(3));
    });
  });

  group('the long-run banner (SPEC §8.1)', () {
    Future<WidgetHarness> pumpRunningFor(
      WidgetTester tester,
      Duration elapsed, {
      Duration threshold = const Duration(hours: 8),
    }) async {
      final running = entry(id: 'r1', start: now.subtract(elapsed));
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
        settings: AppSettings(longRun: threshold),
        running: running,
        entries: <TimeEntry>[running],
      );
      when(
        () => h.writer.setEntryTimes(
          entryId: any(named: 'entryId'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => UndoToken('x', () async {}));
      await h.pump(tester, const TodayScreen());
      return h;
    }

    testWidgets('stays away below the threshold', (tester) async {
      await pumpRunningFor(tester, const Duration(hours: 2));
      expect(find.textContaining('Still tracking'), findsNothing);
    });

    testWidgets('asks once the threshold is passed', (tester) async {
      await pumpRunningFor(tester, const Duration(hours: 9));
      expect(
        find.text('Still tracking Writing specs after 9 h?'),
        findsOneWidget,
      );
    });

    testWidgets('Keep going dismisses it and it stays dismissed', (
      tester,
    ) async {
      await pumpRunningFor(tester, const Duration(hours: 9));

      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Still tracking'), findsNothing);
    });

    testWidgets('a threshold of zero turns it off', (tester) async {
      await pumpRunningFor(
        tester,
        const Duration(hours: 20),
        threshold: Duration.zero,
      );
      expect(find.textContaining('Still tracking'), findsNothing);
    });
  });
}
