import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/backup/json_backup.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/day_rollover.dart';
import '../../domain/timeline/day_window.dart';
import '../db/database.dart';
import '../db/database_provider.dart';
import '../db/mappers.dart';

part 'time_entry_repository.g.dart';

@Riverpod(keepAlive: true)
TimeEntryRepository timeEntryRepository(Ref ref) =>
    TimeEntryRepository(ref.watch(appDatabaseProvider));

/// Read-side access to the timeline. Everything here is a stream query, so the
/// UI reacts to writes with no manual invalidation (SPEC §11.3).
///
/// Writes live exclusively in `TimelineWriter`.
class TimeEntryRepository {
  const TimeEntryRepository(this._db);

  final AppDatabase _db;

  Stream<TimeEntry?> watchRunningEntry() =>
      _db.runningEntry().watchSingleOrNull().map((row) => row?.toDomain());

  /// Entries touching the half-open window `[start, end)`, oldest first.
  Stream<List<TimeEntry>> watchEntriesInRange(DateTime start, DateTime end) =>
      // Generated query takes (rangeEnd, rangeStart) -- the order the variables
      // appear in schema.drift.
      _db
          .entriesInRange(toMillis(end), toMillis(start))
          .watch()
          .map((rows) => rows.map((r) => r.toDomain()).toList());

  Stream<Map<String, Activity>> watchActivitiesById() => _db
      .select(_db.activities)
      .watch()
      .map(
        (rows) => <String, Activity>{
          for (final row in rows) row.id: row.toDomain(),
        },
      );

  Future<TimeEntry?> findEntry(String id) async {
    final row = await (_db.select(
      _db.timeEntries,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row?.toDomain();
  }

  Future<Activity?> findActivity(String id) async {
    final row = await (_db.select(
      _db.activities,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  /// The entries immediately before and after [entryId] on the timeline.
  ///
  /// Looked up from the database rather than from the visible day, so a
  /// neighbour on the other side of midnight is still found.
  Future<({TimeEntry? previous, TimeEntry? next})> neighboursOf(
    String entryId,
    DateTime startUtc,
  ) async {
    final instant = toMillis(startUtc);
    final previous = await _db
        .entryEndingAtOrBefore(entryId, instant)
        .getSingleOrNull();
    final next = await _db
        .entryStartingAfter(entryId, instant)
        .getSingleOrNull();
    return (previous: previous?.toDomain(), next: next?.toDomain());
  }

  /// When the run [running] belongs to actually began, following back through
  /// the entries SPEC §6.11 cut apart at midnight (SPEC §8.1).
  ///
  /// Walks the database rather than the visible day for the same reason
  /// [neighboursOf] does: every hop of this chain is across a midnight by
  /// definition. One hop per day crossed, so the cost is bounded by how long
  /// the clock has been left running and not by the size of the timeline.
  Future<DateTime> runStartOf(
    TimeEntry running, {
    required DayWindowCalculator days,
  }) async {
    var earliest = running;
    while (true) {
      final previous = (await neighboursOf(
        earliest.id,
        earliest.startUtc,
      )).previous;
      if (previous == null) break;
      // Defensive: a chain that did not move backwards would spin forever, and
      // this walk runs on every timeline change.
      if (!previous.startUtc.isBefore(earliest.startUtc)) break;
      if (!isRolloverContinuation(
        entry: earliest,
        previous: previous,
        days: days,
      )) {
        break;
      }
      earliest = previous;
    }
    return earliest.startUtc;
  }

  /// Everything the database holds, tombstones included (SPEC §8.6).
  ///
  /// Deleted rows are part of a backup on purpose: without them a restore would
  /// resurrect everything you ever deleted, and a merge would have no way to
  /// know the deletion was the newer fact.
  Future<({List<BackupActivity> activities, List<BackupEntry> entries})>
  readForBackup() async {
    final activities = await _db.select(_db.activities).get();
    final entries = await _db.select(_db.timeEntries).get();
    return (
      activities: activities.map((row) => row.toBackup()).toList(),
      entries: entries.map((row) => row.toBackup()).toList(),
    );
  }

  Future<TimeEntry?> lastFinishedEntry() async {
    final row = await _db.lastFinishedEntry().getSingleOrNull();
    return row?.toDomain();
  }

  /// Activities ranked for the start sheet (SPEC §9.6).
  ///
  /// `score = sum over recent entries of 0.5 ^ (ageInDays / 7)`, so frequency
  /// and recency both count and neither dominates. Ranking happens in Dart
  /// because the decay is awkward in SQL and the candidate set is small.
  Stream<List<ActivitySuggestion>> watchSuggestions({
    required DateTime now,
    Duration window = const Duration(days: 90),
    String query = '',
    String? excludeActivityId,
  }) {
    final since = now.subtract(window);
    return _db
        .activityUsageSince(toMillis(since))
        .watch()
        .map(
          (rows) => rankSuggestions(
            rows: rows,
            now: now,
            query: query,
            excludeActivityId: excludeActivityId,
          ),
        );
  }

  /// Pure ranking so SPEC §9.6 is unit-testable without a database.
  static List<ActivitySuggestion> rankSuggestions({
    required List<ActivityUsageSinceResult> rows,
    required DateTime now,
    String query = '',
    String? excludeActivityId,
  }) {
    final scores = <String, double>{};
    final lastUsed = <String, DateTime>{};
    final activities = <String, Activity>{};

    for (final row in rows) {
      final activity = row.a.toDomain();
      if (activity.id == excludeActivityId) continue;
      activities[activity.id] = activity;
      final usedAt = DateTime.fromMillisecondsSinceEpoch(
        row.usedAt,
        isUtc: true,
      );
      final ageDays = now.difference(usedAt).inMinutes / (60 * 24);
      scores[activity.id] =
          (scores[activity.id] ?? 0) + math.pow(0.5, ageDays / 7).toDouble();
      final previous = lastUsed[activity.id];
      if (previous == null || usedAt.isAfter(previous)) {
        lastUsed[activity.id] = usedAt;
      }
    }

    final normalizedQuery = Activity.keyFor(query);
    final suggestions = <ActivitySuggestion>[];
    for (final activity in activities.values) {
      final key = activity.nameKey;
      if (normalizedQuery.isNotEmpty && !key.contains(normalizedQuery)) {
        continue;
      }
      suggestions.add(
        ActivitySuggestion(
          activity: activity,
          score: scores[activity.id] ?? 0,
          lastUsed: lastUsed[activity.id],
          isPrefixMatch:
              normalizedQuery.isNotEmpty && key.startsWith(normalizedQuery),
        ),
      );
    }

    suggestions.sort((a, b) {
      // A prefix match always outranks a mere substring match (SPEC §9.6).
      if (a.isPrefixMatch != b.isPrefixMatch) return a.isPrefixMatch ? -1 : 1;
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return (b.lastUsed ?? DateTime.utc(1970)).compareTo(
        a.lastUsed ?? DateTime.utc(1970),
      );
    });
    return suggestions;
  }
}

class ActivitySuggestion {
  const ActivitySuggestion({
    required this.activity,
    required this.score,
    required this.lastUsed,
    required this.isPrefixMatch,
  });

  final Activity activity;
  final double score;
  final DateTime? lastUsed;
  final bool isPrefixMatch;
}
