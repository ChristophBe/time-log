import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/data/db/database.dart';
import 'package:time_log/src/data/db/mappers.dart';

/// SPEC §9.4: one day's entries at 50 000 entries in under 5 ms.
///
/// That budget is for a mid-range phone, and a shared CI runner is neither
/// that nor quiet, so the timing asserted here is looser and is a tripwire for
/// a query that has stopped using its index rather than a benchmark. The query
/// plan is the part that is exact.
///
/// Today is the slow case, not the fast one. The index bounds only
/// `start_utc < rangeEnd` — an entry may cross midnight and be any length, so
/// there is no honest lower bound on its start — and for today that range is
/// every row there is. About 2.5 ms on an M-series Mac at 50 000 entries, and
/// growing with history; a mid-range phone is the device the budget is for.
void main() {
  late AppDatabase db;

  // Twelve entries a day, of 40 minutes each, ending at the newest day.
  const perDay = 12;
  const total = 50000;
  final newest = DateTime.utc(2026, 3, 10);
  final days = total ~/ perDay;

  DateTime dayStart(int daysAgo) => newest.subtract(Duration(days: daysAgo));

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.activities)
        .insert(
          const ActivityRow(
            id: 'a1',
            name: 'Work',
            nameKey: 'work',
            colorSeed: 0,
            archived: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db.batch((batch) {
      for (var d = 0; d < days; d++) {
        for (var i = 0; i < perDay; i++) {
          final start = dayStart(d).add(Duration(hours: 8, minutes: 45 * i));
          batch.insert(
            db.timeEntries,
            TimeEntriesCompanion.insert(
              id: 'e-$d-$i',
              activityId: 'a1',
              startUtc: toMillis(start),
              endUtc: Value(toMillis(start.add(const Duration(minutes: 40)))),
              tzName: 'UTC',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
        }
      }
    });
  });
  tearDownAll(() => db.close());

  /// The median of several runs of one day's query, after a warm-up.
  Future<Duration> timeDay(int daysAgo) async {
    final from = toMillis(dayStart(daysAgo));
    final to = toMillis(dayStart(daysAgo).add(const Duration(days: 1)));
    final runs = <Duration>[];
    for (var i = 0; i < 11; i++) {
      final watch = Stopwatch()..start();
      final rows = await db.entriesInRange(to, from).get();
      watch.stop();
      expect(rows, hasLength(perDay));
      if (i > 0) runs.add(watch.elapsed);
    }
    runs.sort();
    return runs[runs.length ~/ 2];
  }

  test('the day query searches the start index', () async {
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT * FROM time_entries '
          'WHERE deleted_at IS NULL AND start_utc < ? '
          'AND (end_utc IS NULL OR end_utc > ?) ORDER BY start_utc',
          variables: <Variable<Object>>[
            Variable.withInt(1),
            Variable.withInt(0),
          ],
        )
        .get();
    final detail = plan.map((r) => r.read<String>('detail')).join('\n');
    expect(detail, contains('USING INDEX ix_entries_start'));
    expect(detail, isNot(contains('SCAN time_entries\n')));
  });

  test('today, at 50 000 entries', () async {
    final median = await timeDay(0);
    // ignore: avoid_print
    print('SPEC §9.4 day query, today: ${median.inMicroseconds} µs');
    expect(median, lessThan(const Duration(milliseconds: 20)));
  });

  test('a day halfway back, at 50 000 entries', () async {
    final median = await timeDay(days ~/ 2);
    // ignore: avoid_print
    print('SPEC §9.4 day query, halfway: ${median.inMicroseconds} µs');
    expect(median, lessThan(const Duration(milliseconds: 20)));
  });
}
