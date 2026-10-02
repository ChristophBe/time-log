import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/app/theme.dart';
import 'package:time_log/src/core/clock.dart';
import 'package:time_log/src/data/repositories/settings_repository.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/today/today_providers.dart';

class MockTimelineWriter extends Mock implements TimelineWriter {}

/// Widget tests run against fixed provider state and a mock writer rather than a
/// real database.
///
/// Two reasons: drift's queries complete on the real event loop, which deadlocks
/// inside `testWidgets`' fake-async zone; and the database behaviour is already
/// covered end to end by `test/domain/timeline_writer_test.dart` against real
/// sqlite. What is left to check here is rendering, wiring and semantics.
class WidgetHarness {
  WidgetHarness({
    DateTime? now,
    this.settings = const AppSettings(),
    this.running,
    this.entries = const <TimeEntry>[],
    this.activities = const <String, Activity>{},
    this.suggestions = const <ActivitySuggestion>[],
    this.lastFinished,
    this.dayWindows,
  }) : clock = FakeClock(now ?? DateTime.utc(2026, 3, 10, 14, 32));

  final FakeClock clock;
  final AppSettings settings;
  final TimeEntry? running;
  final List<TimeEntry> entries;
  final Map<String, Activity> activities;
  final List<ActivitySuggestion> suggestions;
  final TimeEntry? lastFinished;

  /// Lets a test hand the calendar a 23- or 25-hour day without depending on the
  /// time zone of the machine running the tests.
  final DayWindowCalculator? dayWindows;

  final MockTimelineWriter writer = MockTimelineWriter();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TextScaler textScaler = TextScaler.noScaling,
    Size surfaceSize = const Size(420, 900),
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appClockProvider.overrideWithValue(clock),
          if (dayWindows != null)
            dayWindowsProvider.overrideWithValue(dayWindows!),
          timelineWriterProvider.overrideWithValue(writer),
          appSettingsProvider.overrideWith(
            (ref) => Stream<AppSettings>.value(settings),
          ),
          runningEntryProvider.overrideWith(
            (ref) => Stream<TimeEntry?>.value(running),
          ),
          dayEntriesProvider.overrideWith(
            (ref) => Stream<List<TimeEntry>>.value(entries),
          ),
          activitiesByIdProvider.overrideWith(
            (ref) => Stream<Map<String, Activity>>.value(activities),
          ),
          lastFinishedEntryProvider.overrideWith((ref) async => lastFinished),
          activitySuggestionsProvider.overrideWith(
            (ref, query) => Stream<List<ActivitySuggestion>>.value(
              query.isEmpty
                  ? suggestions
                  : suggestions
                        .where(
                          (s) => s.activity.nameKey.contains(
                            Activity.keyFor(query),
                          ),
                        )
                        .toList(),
            ),
          ),
          secondTickerProvider.overrideWith(
            (ref) => Stream<DateTime>.value(clock.nowUtc()),
          ),
          coarseTickerProvider.overrideWith(
            (ref) => Stream<DateTime>.value(clock.nowUtc()),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          // Override only the text scaler, inside MaterialApp, so the rest of
          // the MediaQuery (notably the surface size) is preserved.
          builder: (context, body) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: body!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Convenience builders for fixtures.
TimeEntry entryFor({
  required String id,
  required String activityId,
  required DateTime start,
  DateTime? end,
  String? note,
}) => TimeEntry(
  id: id,
  activityId: activityId,
  startUtc: start,
  endUtc: end,
  tzName: 'Europe/Berlin',
  note: note,
);

Activity activityFor({
  required String id,
  required String name,
  int colorSeed = 0,
}) => Activity(id: id, name: name, colorSeed: colorSeed);

ActivitySuggestion suggestionFor({
  required Activity activity,
  double score = 1,
  DateTime? lastUsed,
}) => ActivitySuggestion(
  activity: activity,
  score: score,
  lastUsed: lastUsed,
  isPrefixMatch: false,
);
