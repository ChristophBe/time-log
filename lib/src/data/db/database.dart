import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

/// Whether the browser gave us storage that will not survive the tab closing
/// (SPEC §9.5).
///
/// A notifier rather than a provider because it is set from inside the database
/// constructor's callback, before any container exists. False everywhere but
/// the web, where a private window can leave drift with nothing but memory.
final ValueNotifier<bool> webStorageIsTemporary = ValueNotifier<bool>(false);

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-disk database for the current platform.
  ///
  /// The web options are required rather than optional: `drift_flutter` throws if
  /// they are missing on web, since it cannot guess where the WebAssembly module
  /// was put. `sqlite3.wasm` and `drift_worker.js` live in `web/` and are pinned
  /// to the same drift release as the dependency.
  AppDatabase.open()
    : super(
        driftDatabase(
          name: 'time_log',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
            // Which storage the browser actually allowed is worth knowing: a
            // missing OPFS means falling back to IndexedDB, and a private window
            // may give no persistence at all (SPEC §9.5).
            onResult: (result) {
              if (result.missingFeatures.isNotEmpty) {
                debugPrint(
                  'time-log: web storage is ${result.chosenImplementation.name}; '
                  'unavailable: ${result.missingFeatures.join(', ')}',
                );
              }
              // In-memory means a private window or a browser with nothing on
              // offer: the data goes when the tab does, and the app says so
              // rather than letting it look safe (SPEC §9.5).
              webStorageIsTemporary.value =
                  result.chosenImplementation ==
                  WasmStorageImplementation.inMemory;
            },
          ),
        ),
      );

  @override
  int get schemaVersion => 2;

  /// v1 -> v2 adds the two settings SPEC §8.6 lists and nothing stored: the
  /// first day of the week and the long-run threshold.
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
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite, and time_entries.activity_id
      // references activities(id) (SPEC §5.2).
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
