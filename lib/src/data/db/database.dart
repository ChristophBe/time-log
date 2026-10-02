import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-disk database for the current platform. On the web this needs
  /// `web/sqlite3.wasm` and `web/drift_worker.js` to be present.
  AppDatabase.open() : super(driftDatabase(name: 'time_log'));

  @override
  int get schemaVersion => 1;
}
