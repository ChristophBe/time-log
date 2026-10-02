import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:time_log/src/core/clock.dart';
import 'package:time_log/src/core/ids.dart';
import 'package:time_log/src/core/time_zone.dart';
import 'package:time_log/src/data/db/database.dart';
import 'package:time_log/src/data/db/mappers.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline_writer.dart';

/// A [TimelineWriter] over an in-memory database, with a clock the test drives
/// and deterministic row ids.
class TimelineHarness {
  TimelineHarness({DateTime? startAt})
    : clock = FakeClock(startAt ?? DateTime.utc(2026, 3, 10, 9)) {
    db = AppDatabase(NativeDatabase.memory());
    repository = TimeEntryRepository(db);
    writer = TimelineWriter(
      db: db,
      clock: clock,
      ids: SequentialIdGenerator('e'),
      timeZone: const FixedTimeZoneResolver('Europe/Berlin'),
    );
  }

  final FakeClock clock;
  late final AppDatabase db;
  late final TimeEntryRepository repository;
  late final TimelineWriter writer;

  DateTime get now => clock.nowUtc();

  Future<void> close() => db.close();

  /// Every live entry, oldest first.
  Future<List<TimeEntry>> entries() async {
    final rows =
        await (db.select(db.timeEntries)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
            .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  Future<TimeEntry?> running() async =>
      (await db.runningEntry().getSingleOrNull())?.toDomain();

  Future<TimeEntry> byId(String id) async {
    final row = await (db.select(
      db.timeEntries,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.toDomain();
  }

  Future<String> activityNameOf(TimeEntry entry) async =>
      (await repository.findActivity(entry.activityId))!.name;

  /// Total tracked time across every live entry, running ones measured to now.
  Future<Duration> totalTracked() async {
    var total = Duration.zero;
    for (final entry in await entries()) {
      total += entry.durationAt(now);
    }
    return total;
  }
}
