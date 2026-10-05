import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/app_settings.dart';
import '../db/database.dart';
import '../db/database_provider.dart';

part 'settings_repository.g.dart';

/// Settings live in the database rather than in shared preferences so they
/// travel with an export and need no second storage mechanism.
class SettingsRepository {
  const SettingsRepository(this._db);

  final AppDatabase _db;

  static const int _rowId = 1;

  Stream<AppSettings> watch() => (_db.select(
    _db.settingsRow,
  )..where((t) => t.id.equals(_rowId))).watchSingleOrNull().map(_fromRow);

  Future<AppSettings> read() async => _fromRow(
    await (_db.select(
      _db.settingsRow,
    )..where((t) => t.id.equals(_rowId))).getSingleOrNull(),
  );

  Future<void> save(AppSettings settings) => _db
      .into(_db.settingsRow)
      .insertOnConflictUpdate(
        SettingsRowCompanion.insert(
          id: const Value(_rowId),
          snapMinutes: Value(settings.snap.inMinutes),
          use24HourClock: Value(settings.use24HourClock ? 1 : 0),
          themeMode: Value(settings.themeMode.name),
          pixelsPerHour: Value(settings.pixelsPerHour),
          continueMinutes: Value(settings.continueWindow.inMinutes),
          firstDayOfWeek: Value(settings.firstDayOfWeek),
          longRunMinutes: Value(settings.longRun.inMinutes),
        ),
      );

  static AppSettings _fromRow(SettingsRowData? row) {
    if (row == null) return const AppSettings();
    return AppSettings(
      snap: Duration(minutes: row.snapMinutes),
      use24HourClock: row.use24HourClock != 0,
      themeMode: AppThemeMode.values.firstWhere(
        (m) => m.name == row.themeMode,
        orElse: () => AppThemeMode.system,
      ),
      pixelsPerHour: row.pixelsPerHour.clamp(
        AppSettings.minPixelsPerHour,
        AppSettings.maxPixelsPerHour,
      ),
      continueWindow: Duration(minutes: row.continueMinutes),
      firstDayOfWeek: row.firstDayOfWeek,
      longRun: Duration(minutes: row.longRunMinutes),
    );
  }
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
Stream<AppSettings> appSettings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch();
