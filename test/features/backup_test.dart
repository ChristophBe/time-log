import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/backup/json_backup.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/features/backup/backup_providers.dart';
import 'package:time_log/src/features/export/delivery/delivery.dart';
import 'package:time_log/src/features/backup/backup_sheet.dart';
import 'package:time_log/src/features/export/export_providers.dart';
import 'package:time_log/src/features/settings/settings_screen.dart';

import '../support/pump_app.dart';

class _StubSource implements BackupSource {
  _StubSource(this.text);
  String? text;
  int calls = 0;

  @override
  Future<String?> pickBackup() async {
    calls++;
    return text;
  }
}

class _RecordingDelivery implements ExportDelivery {
  String? fileName;
  String? text;
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
  }
}

/// SPEC §8.6: the backup half, through the UI.
void main() {
  final now = DateTime.utc(2026, 3, 11, 12);
  const specs = Activity(id: 'a1', name: 'Writing specs', colorSeed: 0);

  late _RecordingDelivery delivery;
  late _StubSource source;
  late WidgetHarness harness;

  setUp(() {
    delivery = _RecordingDelivery();
    source = _StubSource(null);
  });

  BackupActivity backupActivity() => BackupActivity(
    id: 'a1',
    name: 'Writing specs',
    nameKey: 'writing specs',
    colorSeed: 0,
    archived: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  BackupEntry backupEntry({required String id, required DateTime start}) =>
      BackupEntry(
        id: id,
        activityId: 'a1',
        startUtc: start,
        endUtc: start.add(const Duration(hours: 1)),
        tzName: 'Europe/Berlin',
        createdAt: start,
        updatedAt: start,
      );

  String backupWith(List<BackupEntry> entries) => encodeBackup(
    activities: <BackupActivity>[backupActivity()],
    entries: entries,
    settings: const AppSettings(),
    exportedAt: now,
  );

  /// Settings is a long list now; an item below the fold is not built until
  /// it is scrolled to.
  Future<void> tapSetting(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    harness = WidgetHarness(
      now: now,
      activities: const <String, Activity>{'a1': specs},
    );
    when(() => harness.entryRepository.readForBackup()).thenAnswer(
      (_) async => (
        activities: <BackupActivity>[backupActivity()],
        entries: <BackupEntry>[
          backupEntry(id: 'existing', start: DateTime.utc(2026, 3, 10, 9)),
        ],
      ),
    );
    when(() => harness.writer.applyBackup(any())).thenAnswer((_) async {});
    when(() => harness.writer.deleteAllData()).thenAnswer((_) async {});
    await harness.pump(
      tester,
      const SettingsScreen(),
      extraOverrides: <Override>[
        exportDeliveryProvider.overrideWithValue(delivery),
        backupSourceProvider.overrideWithValue(source),
      ],
    );
  }

  testWidgets('Export everything hands over a JSON backup', (tester) async {
    await pumpSettings(tester);

    await tapSetting(tester, 'Export everything');

    expect(delivery.calls, 1);
    expect(delivery.fileName, 'time-log-backup-2026-03-11.json');
    expect(delivery.text, contains('"formatVersion": 1'));
    expect(delivery.text, contains('Writing specs'));
  });

  testWidgets('a dismissed file dialog does nothing at all', (tester) async {
    await pumpSettings(tester);

    await tapSetting(tester, 'Import a backup…');

    expect(source.calls, 1);
    expect(find.byType(ImportSheet), findsNothing);
    verifyNever(() => harness.writer.applyBackup(any()));
  });

  testWidgets('a good file shows its dry run before applying', (tester) async {
    source.text = backupWith(<BackupEntry>[
      backupEntry(id: 'new', start: DateTime.utc(2026, 3, 11, 9)),
    ]);
    await pumpSettings(tester);

    await tapSetting(tester, 'Import a backup…');

    expect(find.byType(ImportSheet), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    verifyNever(() => harness.writer.applyBackup(any()));

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    verify(() => harness.writer.applyBackup(any())).called(1);
  });

  testWidgets('a file that would break the timeline cannot be applied', (
    tester,
  ) async {
    // Overlaps the entry already in the database.
    source.text = backupWith(<BackupEntry>[
      backupEntry(id: 'clash', start: DateTime.utc(2026, 3, 10, 9, 30)),
    ]);
    await pumpSettings(tester);

    await tapSetting(tester, 'Import a backup…');

    expect(find.byKey(const Key('import-rejection')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Import'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a file from a newer version is refused by name', (tester) async {
    source.text = '{"formatVersion": 99}';
    await pumpSettings(tester);

    await tapSetting(tester, 'Import a backup…');

    expect(find.byType(ImportSheet), findsNothing);
    expect(find.textContaining('newer version'), findsOneWidget);
  });

  testWidgets('Delete all data needs the word typed', (tester) async {
    await pumpSettings(tester);

    await tapSetting(tester, 'Delete all data');

    final button = find.widgetWithText(FilledButton, 'Delete everything');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('delete-all-confirm')), 'nope');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('delete-all-confirm')),
      'delete',
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    verify(() => harness.writer.deleteAllData()).called(1);
  });
}
