import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-disk database for the current platform.
  AppDatabase.open() : super(driftDatabase(name: 'time_log'));

  @override
  int get schemaVersion => 4;

  /// v1 -> v2 adds the two settings SPEC §8.6 lists and nothing stored: the
  /// first day of the week and the long-run threshold.
  ///
  /// v2 -> v3 adds active sessions and the setting that turns them on, which
  /// stays off for anyone upgrading (SPEC §9.9).
  ///
  /// v3 -> v4 adds projects, and every existing entry arrives in none
  /// (SPEC §6.12).
  ///
  /// Written as explicit column additions rather than a table rebuild so that
  /// an upgrade cannot lose a row, and covered by a migration test from a
  /// committed v1 snapshot (SPEC §5.4, §12).
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(settingsRow, settingsRow.firstDayOfWeek);
        await m.addColumn(settingsRow, settingsRow.longRunMinutes);
      }
      if (from < 3) {
        await m.addColumn(settingsRow, settingsRow.trackActiveTime);
        await m.createTable(activeSessions);
        await m.createIndex(uxSessionsSingleOpen);
        await m.createIndex(ixSessionsStart);
      }
      if (from < 4) {
        await m.createTable(projects);
        await m.addColumn(timeEntries, timeEntries.projectId);
      }
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite, and time_entries.activity_id
      // references activities(id) (SPEC §5.2).
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
