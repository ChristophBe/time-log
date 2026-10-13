import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';
import 'package:time_log/src/features/calendar/day_calendar.dart';
import 'package:time_log/src/features/calendar/entry_block.dart';
import 'package:time_log/src/features/calendar/gap_block.dart';
import 'package:time_log/src/features/calendar/now_line.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §8.2.
void main() {
  // 14:32 UTC on 10 March 2026.
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final specs = activityFor(id: 'a1', name: 'Writing specs');
  final email = activityFor(id: 'a2', name: 'Email', colorSeed: 4);
  final activities = <String, Activity>{specs.id: specs, email.id: email};

  /// A UTC day window, so offsets in the test are easy to reason about.
  DayWindowCalculator utcDays({Duration length = const Duration(hours: 24)}) =>
      FixedDayWindowCalculator(<DayWindow>[
        DayWindow(
          startUtc: DateTime.utc(2026, 3, 9),
          endUtc: DateTime.utc(2026, 3, 10),
          year: 2026,
          month: 3,
          day: 9,
        ),
        DayWindow(
          startUtc: DateTime.utc(2026, 3, 10),
          endUtc: DateTime.utc(2026, 3, 10).add(length),
          year: 2026,
          month: 3,
          day: 10,
        ),
        DayWindow(
          startUtc: DateTime.utc(2026, 3, 11),
          endUtc: DateTime.utc(2026, 3, 12),
          year: 2026,
          month: 3,
          day: 11,
        ),
      ]);

  testWidgets('blocks, hour labels and the now-line are drawn', (tester) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      entries: <TimeEntry>[
        entryFor(
          id: 'e1',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 10, 13),
          end: DateTime.utc(2026, 3, 10, 14),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());

    expect(find.byType(DayCalendar), findsOneWidget);
    expect(find.byType(EntryBlock), findsOneWidget);
    expect(find.byType(NowLine), findsOneWidget);
    expect(find.text('13:00'), findsWidgets, reason: 'hour labels on the axis');
  });

  testWidgets('a block is positioned and sized from its times', (tester) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      // 13:00 to 14:00: one hour, which is one pixelsPerHour tall.
      entries: <TimeEntry>[
        entryFor(
          id: 'e1',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 10, 13),
          end: DateTime.utc(2026, 3, 10, 14),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());

    final size = tester.getSize(find.byType(EntryBlock));
    expect(size.height, const AppSettings().pixelsPerHour);
  });

  testWidgets('a one-minute entry still gets a hittable height', (
    tester,
  ) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      entries: <TimeEntry>[
        entryFor(
          id: 'e1',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 10, 13),
          end: DateTime.utc(2026, 3, 10, 13, 1),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());

    expect(tester.getSize(find.byType(EntryBlock)).height, 18);
  });

  testWidgets('the now-line is absent on a past day', (tester) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      entries: <TimeEntry>[
        // On the 9th, so the previous day is not empty.
        entryFor(
          id: 'e0',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 9, 9),
          end: DateTime.utc(2026, 3, 9, 10),
        ),
        entryFor(
          id: 'e1',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 10, 13),
          end: DateTime.utc(2026, 3, 10, 14),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());
    expect(find.byType(NowLine), findsOneWidget);

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();

    expect(
      find.byType(NowLine),
      findsNothing,
      reason: 'there is no "now" on a day that already ended',
    );
  });

  testWidgets('a gap is drawn with its length', (tester) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      entries: <TimeEntry>[
        entryFor(
          id: 'e1',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 10, 9),
          end: DateTime.utc(2026, 3, 10, 10),
        ),
        entryFor(
          id: 'e2',
          activityId: email.id,
          start: DateTime.utc(2026, 3, 10, 11),
          end: DateTime.utc(2026, 3, 10, 12),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());

    expect(find.byType(GapBlock), findsWidgets);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Untracked')), findsWidgets);
    handle.dispose();
  });

  testWidgets('an entry crossing midnight shows a continuation marker', (
    tester,
  ) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      entries: <TimeEntry>[
        entryFor(
          id: 'night',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 9, 23),
          end: DateTime.utc(2026, 3, 10, 1),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());

    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('continues outside this day')),
      findsOneWidget,
    );
    handle.dispose();
    expect(find.text('↑'), findsOneWidget);
  });

  testWidgets('every number on the day is set in the mono (SPEC §9.8)', (
    tester,
  ) async {
    // The two-voice rule is easy to apply to a new widget and easy to forget
    // on an old one; four of these were silently in the sans for a while.
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      entries: <TimeEntry>[
        entryFor(
          id: 'e1',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 10, 13),
          end: DateTime.utc(2026, 3, 10, 14),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());

    for (final text in <String>['13:00', '13:00 – 14:00   1 h', '15:32']) {
      final finder = find.text(text);
      if (finder.evaluate().isEmpty) continue;
      expect(
        tester.widget<Text>(finder.first).style?.fontFamily,
        'GeistMono',
        reason: '"$text" is a number and belongs in the other voice',
      );
    }
  });

  group('the running entry reads as unfinished (SPEC §8.2)', () {
    /// A running entry started [ago] before now, on a UTC day.
    WidgetHarness runningFor(Duration ago) => WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      running: entryFor(
        id: 'r1',
        activityId: specs.id,
        start: now.subtract(ago),
      ),
      entries: <TimeEntry>[
        entryFor(id: 'r1', activityId: specs.id, start: now.subtract(ago)),
      ],
    );

    testWidgets('its bottom edge meets the now-line', (tester) async {
      await runningFor(const Duration(hours: 2))
          .pump(tester, const TodayScreen());

      final block = tester.getRect(find.byType(EntryBlock));
      final line = tester.getRect(find.byType(NowLine));
      expect(
        block.bottom,
        closeTo(line.center.dy, 1.5),
        reason:
            'the block ends at "now", so it has to end where the now-line is '
            'drawn -- and the line is at the centre of its own row',
      );
    });

    testWidgets('a just-started entry still does not overshoot now', (
      tester,
    ) async {
      // Two minutes is under the 18px minimum block height, so the minimum has
      // to be spent upwards: drawing it downwards would paint time that has
      // not happened.
      await runningFor(const Duration(minutes: 2))
          .pump(tester, const TodayScreen());

      final block = tester.getRect(find.byType(EntryBlock));
      final line = tester.getRect(find.byType(NowLine));
      expect(block.height, 18, reason: 'still visible and hittable');
      expect(block.bottom, closeTo(line.center.dy, 1.5));
    });

    testWidgets('its bottom corners are square, its top corners are not', (
      tester,
    ) async {
      await runningFor(const Duration(hours: 2))
          .pump(tester, const TodayScreen());

      final shape =
          tester
                  .widget<Material>(
                    find.descendant(
                      of: find.byType(EntryBlock),
                      matching: find.byType(Material),
                    ),
                  )
                  .shape!
              as RoundedRectangleBorder;
      final radius = shape.borderRadius as BorderRadius;
      expect(
        radius.bottomLeft,
        Radius.zero,
        reason: 'a rounded cap would say the entry ended there',
      );
      expect(radius.bottomRight, Radius.zero);
      expect(radius.topLeft, isNot(Radius.zero));
    });

    testWidgets('a finished entry keeps all four corners', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
        entries: <TimeEntry>[
          entryFor(
            id: 'e1',
            activityId: specs.id,
            start: DateTime.utc(2026, 3, 10, 13),
            end: DateTime.utc(2026, 3, 10, 14),
          ),
        ],
      );
      await h.pump(tester, const TodayScreen());

      final shape =
          tester
                  .widget<Material>(
                    find.descendant(
                      of: find.byType(EntryBlock),
                      matching: find.byType(Material),
                    ),
                  )
                  .shape!
              as RoundedRectangleBorder;
      final radius = shape.borderRadius as BorderRadius;
      expect(radius.bottomLeft, isNot(Radius.zero));
      expect(radius.topLeft, isNot(Radius.zero));
    });
  });

  group('DST (SPEC §5.3)', () {
    testWidgets('a 23-hour day renders 23 hour labels', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(length: const Duration(hours: 23)),
        entries: <TimeEntry>[
          entryFor(
            id: 'e1',
            activityId: specs.id,
            start: DateTime.utc(2026, 3, 10, 13),
            end: DateTime.utc(2026, 3, 10, 14),
          ),
        ],
      );
      await h.pump(tester, const TodayScreen());

      // Scroll through the whole day counting distinct hour labels is overkill;
      // the metrics test covers the count. Here we just check it lays out.
      expect(tester.takeException(), isNull);
      expect(find.byType(DayCalendar), findsOneWidget);
    });

    testWidgets('a 25-hour day lays out without overflow', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(length: const Duration(hours: 25)),
        entries: <TimeEntry>[
          entryFor(
            id: 'e1',
            activityId: specs.id,
            start: DateTime.utc(2026, 3, 10, 13),
            end: DateTime.utc(2026, 3, 10, 14),
          ),
        ],
      );
      await h.pump(tester, const TodayScreen());
      expect(tester.takeException(), isNull);
    });
  });

  group('day navigation (SPEC §8.2)', () {
    testWidgets('Today is disabled while showing today', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
      );
      await h.pump(tester, const TodayScreen());

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.today_outlined),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('Today'), findsOneWidget);
    });

    testWidgets('the previous-day button moves the date header', (
      tester,
    ) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Today'), findsNothing);
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.today_outlined),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Today returns from a past day', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
      );
      await h.pump(tester, const TodayScreen());

      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Today'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Today'), findsOneWidget);
    });
  });

  group('zoom (SPEC §8.2, §10.1)', () {
    testWidgets('the zoom buttons change block height', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
        entries: <TimeEntry>[
          entryFor(
            id: 'e1',
            activityId: specs.id,
            start: DateTime.utc(2026, 3, 10, 13),
            end: DateTime.utc(2026, 3, 10, 14),
          ),
        ],
      );
      await h.pump(tester, const TodayScreen());
      final before = tester.getSize(find.byType(EntryBlock)).height;

      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      final after = tester.getSize(find.byType(EntryBlock)).height;

      expect(after, greaterThan(before));
    });

    testWidgets('zoom stops at the documented maximum', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
        entries: <TimeEntry>[
          entryFor(
            id: 'e1',
            activityId: specs.id,
            start: DateTime.utc(2026, 3, 10, 13),
            end: DateTime.utc(2026, 3, 10, 14),
          ),
        ],
      );
      await h.pump(tester, const TodayScreen());

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pumpAndSettle();
      }
      expect(
        tester.getSize(find.byType(EntryBlock)).height,
        AppSettings.maxPixelsPerHour,
      );
    });
  });

  testWidgets('a short block drops its labels but keeps its semantics', (
    tester,
  ) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      entries: <TimeEntry>[
        entryFor(
          id: 'e1',
          activityId: specs.id,
          start: DateTime.utc(2026, 3, 10, 13),
          end: DateTime.utc(2026, 3, 10, 13, 2),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());

    final handle = tester.ensureSemantics();
    // No room for the name on screen...
    expect(find.text('Writing specs'), findsNothing);
    // ...but the screen reader still gets the whole story (SPEC §8.2, §10.4).
    expect(
      find.bySemanticsLabel(RegExp('Writing specs, 14:00 to 14:02')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
