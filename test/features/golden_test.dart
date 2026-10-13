// Tagged so the goldens can run where they were made. They are pixel-exact
// against the stock comparator, and CI splits them onto a macOS runner while
// everything else runs on Linux (`--tags golden` / `--exclude-tags golden`).
@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/app/router.dart';
import 'package:time_log/src/features/entry/entry_sheet.dart';
import 'package:time_log/src/features/history/history_screen.dart';
import 'package:time_log/src/features/export/export_sheet.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §12: goldens in light and dark at 1.0x and 2.0x text scale.
///
/// These protect the look, which the rest of the suite deliberately does not:
/// every other widget test asserts behaviour and would stay green through a
/// redesign.
///
/// They render in the app's own type: `test/flutter_test_config.dart` loads the
/// vendored families before any test runs, and those are files in the
/// repository, so the goldens stay the same on every machine. Icons are the
/// exception and come out as the test font's boxes -- MaterialIcons lives in the
/// Flutter SDK rather than here, and borrowing it would make these depend on
/// where Flutter is installed.
void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final specs = activityFor(id: 'a1', name: 'Writing specs');
  final email = activityFor(id: 'a2', name: 'Email', colorSeed: 4);
  final standup = activityFor(id: 'a3', name: 'Standup', colorSeed: 8);
  final activities = <String, Activity>{
    specs.id: specs,
    email.id: email,
    standup.id: standup,
  };

  /// A UTC day, so the goldens do not move with the host time zone.
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

  final running = entryFor(
    id: 'e3',
    activityId: specs.id,
    start: DateTime.utc(2026, 3, 10, 13, 20),
    note: 'chapter 3',
  );

  /// Two finished entries with a gap between them, then the running one.
  List<TimeEntry> dayOfWork() => <TimeEntry>[
    entryFor(
      id: 'e1',
      activityId: standup.id,
      start: DateTime.utc(2026, 3, 10, 11),
      end: DateTime.utc(2026, 3, 10, 11, 20),
    ),
    entryFor(
      id: 'e2',
      activityId: email.id,
      start: DateTime.utc(2026, 3, 10, 12),
      end: DateTime.utc(2026, 3, 10, 12, 45),
    ),
    running,
  ];

  WidgetHarness working() => WidgetHarness(
    now: now,
    activities: activities,
    dayWindows: utcDays(),
    running: running,
    entries: dayOfWork(),
  );

  Future<void> expectGolden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final brightness in Brightness.values) {
    final tone = brightness.name;

    testWidgets('today, running ($tone)', (tester) async {
      await working().pump(tester, const TodayScreen(), brightness: brightness);
      await expectGolden(tester, 'today-running-$tone');
    });

    testWidgets('today, nothing running ($tone)', (tester) async {
      final h = WidgetHarness(
        now: now,
        activities: activities,
        dayWindows: utcDays(),
        entries: dayOfWork().sublist(0, 2),
        lastFinished: dayOfWork()[1],
      );
      await h.pump(tester, const TodayScreen(), brightness: brightness);
      await expectGolden(tester, 'today-idle-$tone');
    });

    testWidgets('the entry sheet ($tone)', (tester) async {
      final h = working();
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
              onPressed: () => showEntrySheet(context, dayOfWork()[1]),
              child: const Text('open sheet'),
            ),
          ),
        ),
        brightness: brightness,
      );
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      await expectGolden(tester, 'entry-sheet-$tone');
    });
  }

  // Two of the Apple path, which is a different layout rather than a different
  // palette: the chrome is Liquid Glass and floats, and the day runs underneath
  // it (SPEC §9.8).
  testWidgets('today, running, on Apple', (tester) async {
    await working().pump(tester, const TodayScreen());
    await expectGolden(tester, 'today-running-apple');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the entry sheet, on Apple', (tester) async {
    final h = working();
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
            onPressed: () => showEntrySheet(context, dayOfWork()[1]),
            child: const Text('open sheet'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    await expectGolden(tester, 'entry-sheet-apple');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final brightness in Brightness.values) {
    testWidgets('history (${brightness.name})', (tester) async {
      await WidgetHarness(
        now: now,
        activities: activities,
        entries: dayOfWork(),
      ).pump(tester, const HistoryScreen(), brightness: brightness);
      await expectGolden(tester, 'history-${brightness.name}');
    });
  }

  testWidgets('the navigation shell', (tester) async {
    await WidgetHarness(
      now: now,
      activities: activities,
      entries: dayOfWork(),
    ).pump(tester, const SizedBox.shrink(), routerConfig: buildRouter());
    await expectGolden(tester, 'nav-shell-light');
  });

  testWidgets('today, running, at 2x text scale', (tester) async {
    await working().pump(
      tester,
      const TodayScreen(),
      textScaler: const TextScaler.linear(2),
    );
    await expectGolden(tester, 'today-running-light-2x');
  });

  for (final brightness in Brightness.values) {
    testWidgets('the export sheet (${brightness.name})', (tester) async {
      // Without the fixed day windows the rest of these use: the export sheet
      // asks for a whole week, and a calculator that only knows three days
      // cannot answer for the Sunday the week began on.
      final h = WidgetHarness(
        now: now,
        activities: activities,
        running: running,
        entries: dayOfWork(),
      );
      await h.pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showExportSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
        brightness: brightness,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await expectGolden(tester, 'export-sheet-${brightness.name}');
    });
  }

  testWidgets('the start composer with its suggestions', (tester) async {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      dayWindows: utcDays(),
      running: running,
      entries: dayOfWork(),
      suggestions: <ActivitySuggestion>[
        suggestionFor(
          activity: email,
          lastUsed: now.subtract(const Duration(hours: 2)),
        ),
        suggestionFor(
          activity: standup,
          lastUsed: now.subtract(const Duration(hours: 4)),
        ),
      ],
    );
    await h.pump(tester, const TodayScreen());
    await tester.tap(find.byKey(const Key('start-field')));
    await tester.pumpAndSettle();
    await expectGolden(tester, 'start-composer-light');
  });
}
