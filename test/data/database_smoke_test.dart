import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/data/db/database.dart';

/// Proves the schema-level guarantees from SPEC §4 hold through drift, not just
/// in raw sqlite.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertActivity(String id) => db
      .into(db.activities)
      .insert(
        ActivitiesCompanion.insert(
          id: id,
          name: id,
          nameKey: id,
          colorSeed: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> insertEntry(String id, int start, int? end) => db
      .into(db.timeEntries)
      .insert(
        TimeEntriesCompanion.insert(
          id: id,
          activityId: 'a',
          startUtc: start,
          endUtc: Value(end),
          tzName: 'UTC',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  test('schema creates and the generated column is not written to', () async {
    await insertActivity('a');
    await insertEntry('e1', 100, 200);
    final rows = await db.select(db.timeEntries).get();
    expect(rows, hasLength(1));
    expect(
      rows.single.isRunning,
      null,
      reason: 'a finished entry is not running',
    );
  });

  test('onlyOneRunningEntryEverExists', () async {
    await insertActivity('a');
    await insertEntry('running', 100, null);
    await expectLater(
      insertEntry('second', 300, null),
      throwsA(isA<SqliteException>()),
      reason: 'SPEC §4.1: the unique index on is_running must reject this',
    );
    final running = await db.runningEntry().getSingleOrNull();
    expect(running?.id, 'running');
  });

  test('tombstoning the running entry frees the running slot', () async {
    await insertActivity('a');
    await insertEntry('running', 100, null);
    await db.customStatement(
      'UPDATE time_entries SET deleted_at = 1 WHERE id = ?',
      ['running'],
    );
    await insertEntry('next', 300, null);
    final running = await db.runningEntry().getSingleOrNull();
    expect(running?.id, 'next');
  });

  test('endIsAlwaysAfterStart', () async {
    await insertActivity('a');
    await expectLater(
      insertEntry('bad', 500, 400),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertEntry('zero', 500, 500),
      throwsA(isA<SqliteException>()),
    );
  });
}
