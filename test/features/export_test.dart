import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/project.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/features/export/delivery/delivery.dart';
import 'package:time_log/src/features/export/export_providers.dart';
import 'package:time_log/src/features/export/export_sheet.dart';
import 'package:time_log/src/features/settings/settings_screen.dart';

import '../support/pump_app.dart';

/// Records what it was asked to send instead of touching a platform channel.
class _RecordingDelivery implements ExportDelivery {
  String? fileName;
  String? text;
  String? mimeType;
  int calls = 0;

  @override
  Future<void> send({
    required String fileName,
    required String text,
    required String mimeType,
  }) async {
    calls++;
    this.fileName = fileName;
    this.text = text;
    this.mimeType = mimeType;
  }
}

/// SPEC §8.6: exporting a date range.
void main() {
  // A Wednesday, so "this week" has days on both sides of it.
  final now = DateTime.utc(2026, 3, 11, 12);
  const specs = Activity(id: 'a1', name: 'Writing specs', colorSeed: 0);

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

  late WidgetHarness harness;
  late MockTimeEntryRepository repository;
  late _RecordingDelivery delivery;

  setUp(() => delivery = _RecordingDelivery());

  /// The harness owns the repository mock and already overrides its provider —
  /// overriding one provider twice in a container is an error — so the entries
  /// go in when the harness is built rather than through a later `when`.
  Future<void> pumpWith(
    WidgetTester tester,
    Widget child, {
    List<TimeEntry> entries = const <TimeEntry>[],
    Map<String, Activity> activities = const <String, Activity>{'a1': specs},
    Map<String, Project> projects = const <String, Project>{},
  }) async {
    harness = WidgetHarness(
      now: now,
      activities: activities,
      projects: projects,
      entries: entries,
    );
    repository = harness.entryRepository;
    await harness.pump(
      tester,
      child,
      extraOverrides: <Override>[
        exportDeliveryProvider.overrideWithValue(delivery),
      ],
    );
  }

  /// The range the sheet asked the repository for, captured from the mock.
  ({DateTime from, DateTime to}) requestedRange() {
    final call = verify(
      () => repository.watchEntriesInRange(captureAny(), captureAny()),
    )..called(greaterThan(0));
    final captured = call.captured;
    return (
      from: captured[captured.length - 2] as DateTime,
      to: captured.last as DateTime,
    );
  }

  Future<void> pumpSheet(
    WidgetTester tester, {
    List<TimeEntry> entries = const <TimeEntry>[],
    Map<String, Activity> activities = const <String, Activity>{'a1': specs},
    Map<String, Project> projects = const <String, Project>{},
  }) async {
    await pumpWith(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showExportSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
      entries: entries,
      activities: activities,
      projects: projects,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the default range is this week, to today', (tester) async {
    await pumpSheet(tester);

    final range = requestedRange();
    // 11 March 2026 is a Wednesday; the test locale starts weeks on Sunday, so
    // the week began on the 8th and ends at the end of the 11th.
    expect(range.from.toLocal().day, 8);
    expect(range.to.toLocal(), DateTime(2026, 3, 12));
  });

  testWidgets('last month spans the whole of the previous month', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.tap(find.text('Last month'));
    await tester.pumpAndSettle();

    final range = requestedRange();
    expect(range.from.toLocal(), DateTime(2026, 2));
    expect(
      range.to.toLocal(),
      DateTime(2026, 3),
      reason: 'February has 28 days in 2026, and the range ends at its end',
    );
  });

  testWidgets('the summary counts what the file will contain', (tester) async {
    await pumpSheet(
      tester,
      entries: <TimeEntry>[
        entry(
          id: 'e1',
          start: DateTime.utc(2026, 3, 9, 9),
          end: DateTime.utc(2026, 3, 9, 10, 30),
        ),
        entry(
          id: 'e2',
          start: DateTime.utc(2026, 3, 10, 9),
          end: DateTime.utc(2026, 3, 10, 10),
        ),
      ],
    );

    expect(find.textContaining('2 entries'), findsOneWidget);
    expect(find.textContaining('2 h 30 min'), findsOneWidget);
  });

  testWidgets('an empty range says so and cannot be exported', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Nothing tracked in this range'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Export CSV'))
          .onPressed,
      isNull,
      reason: 'a file with only a header is not worth handing over',
    );
    expect(delivery.calls, 0);
  });

  testWidgets('Export hands the file to the platform once', (tester) async {
    await pumpSheet(
      tester,
      entries: <TimeEntry>[
        entry(
          id: 'e1',
          start: DateTime.utc(2026, 3, 10, 9),
          end: DateTime.utc(2026, 3, 10, 10),
        ),
      ],
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Export CSV'));
    await tester.pumpAndSettle();

    expect(delivery.calls, 1);
    expect(delivery.mimeType, 'text/csv');
    expect(delivery.fileName, 'time-log-2026-03-08_2026-03-11.csv');
    expect(delivery.text, contains('Writing specs'));
    expect(find.textContaining('Exported 1 entries'), findsOneWidget);
  });

  group('by project (SPEC §8.6)', () {
    const clientA = Project(id: 'p1', name: 'Client A');
    const email = Activity(id: 'a2', name: 'Email', colorSeed: 1);
    final filed = <String, Activity>{'a1': specs, 'a2': email};
    // The first entry is in Client A, the second in no project.
    final twoEntries = <TimeEntry>[
      entry(
        id: 'e1',
        start: DateTime.utc(2026, 3, 10, 9),
        end: DateTime.utc(2026, 3, 10, 10),
      ).withProject('p1'),
      TimeEntry(
        id: 'e2',
        activityId: 'a2',
        startUtc: DateTime.utc(2026, 3, 10, 10),
        endUtc: DateTime.utc(2026, 3, 10, 10, 30),
        tzName: 'Europe/Berlin',
      ),
    ];

    Future<void> pumpFiled(WidgetTester tester) => pumpSheet(
      tester,
      entries: twoEntries,
      activities: filed,
      projects: const <String, Project>{'p1': clientA},
    );

    testWidgets('there is no project choice until a project exists', (
      tester,
    ) async {
      await pumpSheet(tester, entries: twoEntries);

      expect(find.text('Project'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'No project'), findsNothing);
    });

    testWidgets('All is chosen to begin with, and counts everything', (
      tester,
    ) async {
      await pumpFiled(tester);

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
            .selected,
        isTrue,
      );
      expect(find.textContaining('2 entries'), findsOneWidget);
    });

    testWidgets('picking a project narrows the summary and names the file', (
      tester,
    ) async {
      await pumpFiled(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Client A'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 entry'), findsOneWidget);
      expect(find.textContaining('1 h'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Export CSV'));
      await tester.pumpAndSettle();

      expect(delivery.fileName, 'time-log-client-a-2026-03-08_2026-03-11.csv');
      expect(delivery.text, contains('Writing specs,Client A,'));
      expect(delivery.text, isNot(contains('Email')));
    });

    testWidgets('No project exports what is in none', (tester) async {
      await pumpFiled(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'No project'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Export CSV'));
      await tester.pumpAndSettle();

      expect(
        delivery.fileName,
        'time-log-no-project-2026-03-08_2026-03-11.csv',
      );
      expect(delivery.text, contains('Email'));
      expect(delivery.text, isNot(contains('Writing specs')));
    });
  });

  testWidgets('it is reachable from Settings', (tester) async {
    await pumpWith(tester, const SettingsScreen());

    // Settings is a long list; the item has to be scrolled to before it is
    // built.
    await tester.scrollUntilVisible(
      find.text('Export entries…'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export entries…'));
    await tester.pumpAndSettle();

    expect(find.byType(ExportSheet), findsOneWidget);
  });

  Future<void> pumpSheetWithAnEntry(WidgetTester tester) => pumpSheet(
    tester,
    entries: <TimeEntry>[
      entry(
        id: 'e1',
        start: DateTime.utc(2026, 3, 10, 9),
        end: DateTime.utc(2026, 3, 10, 10),
      ),
    ],
  );

  testWidgets('the sheet meets SPEC §10 on labelling and targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSheetWithAnEntry(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  // With the goldens because, like them, it depends on the rasteriser: the
  // guideline takes the commonest dark pixel at 1x as the text colour, and on
  // Linux that can be an anti-aliasing grey rather than the ink, failing 12 pt
  // Geist at 2:1 on colours that are really 8:1.
  testWidgets('the sheet meets SPEC §10 on contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSheetWithAnEntry(tester);

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }, tags: <String>['golden']);
}
