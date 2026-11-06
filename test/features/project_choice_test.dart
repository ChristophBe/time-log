import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/project.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/entry/entry_sheet.dart';
import 'package:time_log/src/features/today/today_screen.dart';

import '../support/pump_app.dart';

/// SPEC §6.12, §8.1, §8.3, §8.4: choosing an entry's project when starting,
/// while it runs, and afterwards.
void main() {
  final now = DateTime.utc(2026, 3, 10, 14, 32);
  final specs = activityFor(id: 'a1', name: 'Writing specs', colorSeed: 0);
  final email = activityFor(id: 'a2', name: 'Email', colorSeed: 1);
  final activities = <String, Activity>{specs.id: specs, email.id: email};
  const projects = <String, Project>{
    'p1': Project(id: 'p1', name: 'Client A'),
    'p2': Project(id: 'p2', name: 'Client B'),
  };

  final chip = find.byKey(const Key('project-chip'));

  /// Running since 13:00, in Client A.
  final runningInA = entryFor(
    id: 'r1',
    activityId: specs.id,
    start: DateTime.utc(2026, 3, 10, 13),
  ).withProject('p1');

  WidgetHarness harness({
    Map<String, Project> projects = projects,
    TimeEntry? running,
    Map<String, String?> latest = const <String, String?>{},
    bool onCalendar = true,
  }) {
    final h = WidgetHarness(
      now: now,
      activities: activities,
      projects: projects,
      running: running,
      entries: <TimeEntry>[if (onCalendar) ?running],
      latestProjectByActivity: latest,
      suggestions: <ActivitySuggestion>[
        suggestionFor(activity: email, lastUsed: now),
      ],
    );
    when(
      () => h.writer.startByName(
        name: any(named: 'name'),
        projectId: any(named: 'projectId'),
      ),
    ).thenAnswer(
      (_) async => const StartOutcome(
        mode: StartMode.started,
        entryId: 'new',
        activityName: 'Email',
      ),
    );
    when(
      () => h.writer.setEntryProject(
        entryId: any(named: 'entryId'),
        projectId: any(named: 'projectId'),
      ),
    ).thenAnswer((_) async => UndoToken('x', () async {}));
    return h;
  }

  Future<void> choose(WidgetTester tester, Finder opener, String id) async {
    await tester.tap(opener);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('project-option-$id')).last);
    await tester.pumpAndSettle();
  }

  String chipLabel(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: chip, matching: find.byType(Text)))
      .data!;

  group('the composer (SPEC §8.3)', () {
    testWidgets('has no project chip until a project exists', (tester) async {
      await harness(projects: const <String, Project>{})
          .pump(tester, const TodayScreen());

      expect(chip, findsNothing);
    });

    testWidgets('suggests the latest project, and starts in it', (
      tester,
    ) async {
      final h = harness(running: runningInA);
      await h.pump(tester, const TodayScreen());

      expect(chipLabel(tester), 'Client A', reason: 'what is running now');

      await tester.enterText(find.byKey(const Key('start-field')), 'Reading');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-button')));
      await tester.pumpAndSettle();

      verify(() => h.writer.startByName(name: 'Reading', projectId: 'p1'))
          .called(1);
    });

    testWidgets('a known activity brings its own latest project', (
      tester,
    ) async {
      final h = harness(
        running: runningInA,
        latest: <String, String?>{email.id: 'p2'},
      );
      await h.pump(tester, const TodayScreen());

      await tester.enterText(find.byKey(const Key('start-field')), 'email');
      await tester.pumpAndSettle();
      expect(chipLabel(tester), 'Client B');

      await tester.tap(find.text('Email').last);
      await tester.pumpAndSettle();

      verify(() => h.writer.startByName(name: 'Email', projectId: 'p2'))
          .called(1);
    });

    testWidgets('a project picked in the chip wins, then resets', (
      tester,
    ) async {
      final h = harness(running: runningInA);
      await h.pump(tester, const TodayScreen());

      await choose(tester, chip, 'none');
      expect(chipLabel(tester), 'No project');
      await tester.enterText(find.byKey(const Key('start-field')), 'Reading');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-button')));
      await tester.pumpAndSettle();

      verify(() => h.writer.startByName(name: 'Reading', projectId: null))
          .called(1);
      expect(chipLabel(tester), 'Client A', reason: 'back to the default');
    });
  });

  group('the running band (SPEC §8.1)', () {
    final bandProject = find.byKey(const Key('running-project'));

    testWidgets('shows the running entry\'s project', (tester) async {
      await harness(running: runningInA).pump(tester, const TodayScreen());

      expect(
        find.descendant(of: bandProject, matching: find.text('Client A')),
        findsOneWidget,
      );
    });

    testWidgets('changes only the running entry, with undo', (tester) async {
      final h = harness(running: runningInA);
      await h.pump(tester, const TodayScreen());

      await choose(tester, bandProject, 'p2');

      verify(() => h.writer.setEntryProject(entryId: 'r1', projectId: 'p2'))
          .called(1);
      expect(find.text('Moved to Client B'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('is not a menu without projects', (tester) async {
      await harness(
        projects: const <String, Project>{},
        running: runningInA,
      ).pump(tester, const TodayScreen());

      expect(bandProject, findsNothing);
      expect(find.text('No project'), findsNothing);
    });
  });

  testWidgets('the entry sheet moves one entry to no project (SPEC §8.4)', (
    tester,
  ) async {
    final entry = entryFor(
      id: 'e1',
      activityId: specs.id,
      start: DateTime.utc(2026, 3, 10, 9),
      end: DateTime.utc(2026, 3, 10, 10),
    ).withProject('p1');
    final h = harness();
    await h.pump(tester, Scaffold(body: EntrySheet(entry: entry)));

    expect(chipLabel(tester), 'Client A');
    await choose(tester, chip, 'none');

    verify(() => h.writer.setEntryProject(entryId: 'e1', projectId: null))
        .called(1);
    expect(chipLabel(tester), 'No project');
  });

  testWidgets('the chips meet SPEC §10', (tester) async {
    final handle = tester.ensureSemantics();
    // Off the calendar, whose gap blocks are not what is under test here.
    await harness(
      running: runningInA,
      onCalendar: false,
    ).pump(tester, const TodayScreen());

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
