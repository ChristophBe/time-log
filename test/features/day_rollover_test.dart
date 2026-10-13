import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/today/day_rollover.dart';
import 'package:time_log/src/features/today/today_providers.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §6.11's rollover as the screen sees it: the day following midnight
/// (§8.2) and the long-run banner measuring across a cut (§8.1).
void main() {
  const specs = Activity(id: 'a1', name: 'Writing specs', colorSeed: 0);
  const activities = <String, Activity>{'a1': specs};

  setUpAll(() {
    registerFallbackValue(const LocalDayWindowCalculator());
  });

  DayWindowCalculator utcDays() => FixedDayWindowCalculator(<DayWindow>[
    for (final day in <int>[9, 10, 11])
      DayWindow(
        startUtc: DateTime.utc(2026, 3, day),
        endUtc: DateTime.utc(2026, 3, day + 1),
        year: 2026,
        month: 3,
        day: day,
      ),
  ]);

  TimeEntry entry({
    required String id,
    required DateTime start,
    DateTime? end,
  }) => TimeEntry(
    id: id,
    activityId: specs.id,
    startUtc: start,
    endUtc: end,
    tzName: 'UTC',
  );

  /// Nothing to cut: these tests are about what the screen does afterwards, and
  /// the cutting itself is covered against real sqlite in
  /// `test/domain/timeline_writer_test.dart`.
  void stubRollover(WidgetHarness h) {
    when(() => h.writer.rollOverRunningEntry(days: any(named: 'days')))
        .thenAnswer((_) async => const RolloverOutcome.nothingToDo());
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TodayScreen)));

  group('the day follows midnight (SPEC §8.2)', () {
    testWidgets('theSelectedDayFollowsMidnight', (tester) async {
      final h = WidgetHarness(
        now: DateTime.utc(2026, 3, 10, 23, 50),
        activities: activities,
        dayWindows: utcDays(),
      );
      stubRollover(h);
      await h.pump(tester, const TodayScreen());
      expect(find.text('Today'), findsOneWidget);

      h.clock.setTo(DateTime.utc(2026, 3, 11, 0, 5));
      await containerOf(tester).read(dayRolloverProvider.notifier).check();
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(selectedDayProvider).day, 11);
      expect(
        find.text('Today'),
        findsOneWidget,
        reason:
            'the header moved with the clock instead of stranding '
            'yesterday with no now-line',
      );
    });

    testWidgets('a day you navigated to is left where you put it', (
      tester,
    ) async {
      final h = WidgetHarness(
        now: DateTime.utc(2026, 3, 10, 23, 50),
        activities: activities,
        dayWindows: utcDays(),
      );
      stubRollover(h);
      await h.pump(tester, const TodayScreen());

      containerOf(tester).read(selectedDayProvider.notifier).previousDay();
      await tester.pumpAndSettle();
      expect(containerOf(tester).read(selectedDayProvider).day, 9);

      h.clock.setTo(DateTime.utc(2026, 3, 11, 0, 5));
      await containerOf(tester).read(dayRolloverProvider.notifier).check();
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(selectedDayProvider).day,
        9,
        reason: 'only a view still tracking today is carried across midnight',
      );
    });
  });

  group('the long-run banner across a cut (SPEC §8.1)', () {
    testWidgets('longRunBannerMeasuresTheRolloverChain', (tester) async {
      // Started at 22:00 yesterday and cut at midnight, so the running entry
      // is six hours old while the run is eight.
      final running = entry(id: 'r2', start: DateTime.utc(2026, 3, 11));
      final h = WidgetHarness(
        now: DateTime.utc(2026, 3, 11, 6),
        activities: activities,
        dayWindows: utcDays(),
        running: running,
        entries: <TimeEntry>[running],
        runStart: DateTime.utc(2026, 3, 10, 22),
      );
      stubRollover(h);
      await h.pump(tester, const TodayScreen());

      expect(
        find.text('Still tracking Writing specs after 8 h?'),
        findsOneWidget,
        reason: 'the overnight clock is the case this banner exists for',
      );
    });

    testWidgets('Keep going stays pressed across the next cut', (tester) async {
      // A run begun on the 9th and already cut once, so the entry on screen
      // starts later than the run does. Both halves are over the threshold on
      // their own, which leaves the surviving dismissal as the only thing
      // keeping the banner away after the second cut.
      final before = entry(id: 'r1', start: DateTime.utc(2026, 3, 10));
      final after = entry(id: 'r2', start: DateTime.utc(2026, 3, 11));
      // Synchronous and broadcast so an event lands in the frame that follows
      // it: the whole point of this test is to push a second running entry
      // into a tree that is already mounted and dismissed.
      final running = StreamController<TimeEntry?>.broadcast(sync: true);
      addTearDown(running.close);

      final h = WidgetHarness(
        now: DateTime.utc(2026, 3, 11, 9),
        activities: activities,
        dayWindows: utcDays(),
        running: before,
        entries: <TimeEntry>[before],
        runStart: DateTime.utc(2026, 3, 9, 22),
        settings: const AppSettings(longRun: Duration(hours: 8)),
        runningStream: running.stream,
      );
      stubRollover(h);
      await h.pump(tester, const TodayScreen());
      running.add(before);
      await tester.pumpAndSettle();
      expect(find.textContaining('Still tracking'), findsOneWidget);

      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Still tracking'), findsNothing);

      // Midnight cuts the entry and hands the banner a brand-new id. The run
      // it was dismissed for has not changed.
      running.add(after);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Still tracking'),
        findsNothing,
        reason: 'SPEC §6.11: a cut is not a reason to ask again',
      );
    });
  });
}
