import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;
import 'package:time_log/src/data/db/database.dart';
import 'package:time_log/src/data/db/mappers.dart';
import 'package:time_log/src/domain/timeline/invariants.dart';

/// SPEC §5.4 and §12: a database written by an older version still opens, and
/// still satisfies §4 afterwards.
///
/// The v1 schema is written out here verbatim rather than generated, so the
/// test keeps working even if the current schema file is edited — which is the
/// whole point of a migration test.
const String _v1Schema = '''
CREATE TABLE activities (
  id         TEXT    NOT NULL PRIMARY KEY,
  name       TEXT    NOT NULL,
  name_key   TEXT    NOT NULL UNIQUE,
  color_seed INTEGER NOT NULL,
  archived   INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE time_entries (
  id          TEXT    NOT NULL PRIMARY KEY,
  activity_id TEXT    NOT NULL REFERENCES activities(id),
  note        TEXT,
  start_utc   INTEGER NOT NULL,
  end_utc     INTEGER,
  tz_name     TEXT    NOT NULL,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  deleted_at  INTEGER,
  is_running  INTEGER GENERATED ALWAYS AS (
                CASE WHEN end_utc IS NULL AND deleted_at IS NULL THEN 1 END) VIRTUAL,
  CHECK (end_utc IS NULL OR end_utc > start_utc)
);
CREATE UNIQUE INDEX ux_entries_single_running ON time_entries (is_running);
CREATE        INDEX ix_entries_start          ON time_entries (start_utc);
CREATE        INDEX ix_entries_activity_start ON time_entries (activity_id, start_utc);
CREATE TABLE settings_row (
  id                INTEGER NOT NULL PRIMARY KEY DEFAULT 1,
  snap_minutes      INTEGER NOT NULL DEFAULT 5,
  use24HourClock    INTEGER NOT NULL DEFAULT 1,
  theme_mode        TEXT    NOT NULL DEFAULT 'system',
  pixels_per_hour   REAL    NOT NULL DEFAULT 72.0,
  continue_minutes  INTEGER NOT NULL DEFAULT 5,
  CHECK (id = 1)
);
''';

void main() {
  late QueryExecutor executor;
  late AppDatabase db;

  /// A v1 database with a day of entries in it.
  ///
  /// Built through raw sqlite rather than through drift: opening an
  /// `AppDatabase` is what *runs* the migration, so the old shape has to exist
  /// before drift ever sees the connection.
  void createV1() {
    final sqlite = raw_sqlite.sqlite3.openInMemory();
    for (final statement in _v1Schema.split(';')) {
      if (statement.trim().isEmpty) continue;
      sqlite.execute(statement);
    }
    sqlite.execute('PRAGMA user_version = 1');
    sqlite.execute(
      'INSERT INTO activities VALUES '
      "('a1', 'Writing specs', 'writing specs', 0, 0, 1000, 1000)",
    );
    sqlite.execute(
      'INSERT INTO time_entries (id, activity_id, start_utc, end_utc, '
      'tz_name, created_at, updated_at) VALUES '
      "('e1', 'a1', 1000000, 4600000, 'Europe/Berlin', 1000, 1000)",
    );
    sqlite.execute(
      'INSERT INTO time_entries (id, activity_id, start_utc, end_utc, '
      'tz_name, created_at, updated_at) VALUES '
      "('e2', 'a1', 4600000, 8200000, 'Europe/Berlin', 1000, 1000)",
    );
    sqlite.execute('INSERT INTO settings_row (id) VALUES (1)');
    executor = NativeDatabase.opened(sqlite);
  }

  setUp(() {
    createV1();
    db = AppDatabase(executor);
  });

  tearDown(() => db.close());

  test('a v1 database opens, and its entries survive', () async {
    final entries = await db.select(db.timeEntries).get();

    expect(entries, hasLength(2));
    expect(entries.first.id, 'e1');
    expect(entries.first.tzName, 'Europe/Berlin');
  });

  test('the new settings arrive with their defaults', () async {
    final settings = await db.select(db.settingsRow).getSingle();

    expect(settings.firstDayOfWeek, 0, reason: 'follow the locale');
    expect(settings.longRunMinutes, 480, reason: 'eight hours');
    expect(settings.snapMinutes, 5, reason: 'and the old ones are untouched');
  });

  test('SPEC §4 still holds after the upgrade', () async {
    final entries = (await db.select(db.timeEntries).get())
        .map((row) => row.toDomain())
        .toList();

    checkNoOverlap(entries);
    checkSingleRunning(entries);
  });

  test('the single-running index survives the upgrade', () async {
    // The invariant that lives in the schema rather than in Dart (SPEC §4.1).
    await db.customStatement(
      'INSERT INTO time_entries (id, activity_id, start_utc, tz_name, '
      'created_at, updated_at) VALUES '
      "('r1', 'a1', 9000000, 'Europe/Berlin', 1000, 1000)",
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO time_entries (id, activity_id, start_utc, tz_name, '
        'created_at, updated_at) VALUES '
        "('r2', 'a1', 9500000, 'Europe/Berlin', 1000, 1000)",
      ),
      throwsA(anything),
    );
  });
}
