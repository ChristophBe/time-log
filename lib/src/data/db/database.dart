import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

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
            },
          ),
        ),
      );

  @override
  int get schemaVersion => 1;
}
