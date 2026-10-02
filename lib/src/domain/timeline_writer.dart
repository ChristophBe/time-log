import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../core/time_zone.dart';
import '../data/db/database.dart';
import '../data/db/database_provider.dart';
import '../data/db/mappers.dart';
import 'models/activity.dart';
import 'models/time_entry.dart';
import 'timeline/continue_rule.dart';
import 'timeline/invariants.dart';
import 'timeline/timeline_math.dart';

part 'timeline_writer.g.dart';

@Riverpod(keepAlive: true)
TimelineWriter timelineWriter(Ref ref) => TimelineWriter(
  db: ref.watch(appDatabaseProvider),
  clock: ref.watch(appClockProvider),
  ids: ref.watch(idGeneratorProvider),
  timeZone: ref.watch(timeZoneResolverProvider),
);

/// Undoes one user-visible operation.
///
/// A shared-boundary drag moved two entries but is one token, so one tap of
/// Undo puts both back (SPEC §7.5).
class UndoToken {
  const UndoToken(this.description, this._undo);

  final String description;
  final Future<void> Function() _undo;

  Future<void> undo() => _undo();
}

/// Thrown when an undo can no longer be applied because the timeline moved on
/// (for example something else is running now).
class UndoNoLongerPossible implements Exception {
  const UndoNoLongerPossible(this.reason);

  final String reason;

  @override
  String toString() => 'UndoNoLongerPossible: $reason';
}

enum StartMode {
  /// A new entry began; nothing was running.
  started,

  /// A new entry began and the previous one was stopped at the same instant.
  switched,

  /// The previous entry was under a minute old, so it was a mis-start and the
  /// new entry took its place (SPEC §6.1).
  replacedMisstart,

  /// That activity was already running; nothing changed.
  alreadyRunning,
}

class StartOutcome {
  const StartOutcome({
    required this.mode,
    required this.entryId,
    required this.activityName,
    this.stoppedActivityName,
    this.undo,
  });

  final StartMode mode;
  final String entryId;
  final String activityName;
  final String? stoppedActivityName;
  final UndoToken? undo;
}

class StopOutcome {
  const StopOutcome({
    required this.stopped,
    this.entryId,
    this.activityName,
    this.duration,
    this.undo,
  });

  const StopOutcome.nothingRunning() : this(stopped: false);

  final bool stopped;
  final String? entryId;
  final String? activityName;
  final Duration? duration;
  final UndoToken? undo;

  /// Under a minute, so the UI offers "Discard" alongside Undo (SPEC §6.2).
  bool get wasVeryShort => duration != null && duration! < kMinEntryLength;
}

class MoveOutcome {
  const MoveOutcome({
    required this.wasClamped,
    required this.appliedUtc,
    required this.undo,
  });

  final bool wasClamped;
  final DateTime appliedUtc;
  final UndoToken undo;
}

/// The only code that mutates `time_entries` or `activities` (SPEC §11.3).
///
/// Every method is one transaction that reads the affected neighbourhood,
/// computes the new state with the pure functions in `domain/timeline/`,
/// re-checks the SPEC §4 invariants, writes, and returns an [UndoToken]. If a
/// check fails the transaction rolls back, so the timeline is never left
/// half-changed (SPEC §4.6).
class TimelineWriter {
  TimelineWriter({
    required AppDatabase db,
    required AppClock clock,
    required IdGenerator ids,
    required TimeZoneResolver timeZone,
  }) // Named parameters cannot be private, so initializing formals are not an
    // option for these fields.
    // ignore: prefer_initializing_formals
    : _db = db,
       // ignore: prefer_initializing_formals
       _clock = clock,
       // ignore: prefer_initializing_formals
       _ids = ids,
       // ignore: prefer_initializing_formals
       _timeZone = timeZone;

  final AppDatabase _db;
  final AppClock _clock;
  final IdGenerator _ids;
  final TimeZoneResolver _timeZone;

  String? _cachedZone;

  Future<String> _zone() async => _cachedZone ??= await _timeZone.currentZone();

  // ---------------------------------------------------------------- starting

  /// Starts [name], creating the activity if it is new. Stops whatever was
  /// running, at exactly this entry's start instant (SPEC §4.4, §6.1).
  Future<StartOutcome> startByName({required String name, String? note}) async {
    if (!Activity.isValidName(name)) {
      throw ArgumentError.value(name, 'name', 'not a usable activity name');
    }
    final zone = await _zone();
    return _db.transaction(() async {
      final activity = await _findOrCreateActivity(name);
      return _start(activity: activity, note: note, zone: zone);
    });
  }

  /// Resume: a *new* entry copying an existing entry's activity and note, so the
  /// original span stays in history untouched (SPEC §6.3).
  Future<StartOutcome> resume(String entryId) async {
    final zone = await _zone();
    return _db.transaction(() async {
      final source = await _requireEntry(entryId);
      final activity = await _requireActivity(source.activityId);
      return _start(activity: activity, note: source.note, zone: zone);
    });
  }

  Future<StartOutcome> _start({
    required Activity activity,
    required String? note,
    required String zone,
  }) async {
    final now = _clock.nowUtc();
    final runningRow = await _db.runningEntry().getSingleOrNull();
    final before = <TimeEntryRow>[];
    var mode = StartMode.started;
    var startUtc = now;
    String? stoppedName;

    if (runningRow != null) {
      final running = runningRow.toDomain();
      if (running.activityId == activity.id &&
          (running.note ?? '') == (note ?? '')) {
        return StartOutcome(
          mode: StartMode.alreadyRunning,
          entryId: running.id,
          activityName: activity.name,
        );
      }
      before.add(runningRow);
      stoppedName = (await _requireActivity(running.activityId)).name;

      if (now.difference(running.startUtc) < kMinEntryLength) {
        // A mis-start corrected seconds later should not litter the timeline:
        // the new entry takes the old one's place and its start (SPEC §6.1).
        await _softDelete(running.id, now);
        startUtc = running.startUtc;
        mode = StartMode.replacedMisstart;
      } else {
        // Handover with no gap and no overlap (SPEC §4.4).
        await _setEnd(running.id, now);
        mode = StartMode.switched;
      }
    }

    final id = _ids.next();
    await _db
        .into(_db.timeEntries)
        .insert(
          TimeEntriesCompanion.insert(
            id: id,
            activityId: activity.id,
            note: Value(note),
            startUtc: toMillis(startUtc),
            endUtc: const Value(null),
            tzName: zone,
            createdAt: toMillis(now),
            updatedAt: toMillis(now),
          ),
        );

    await _validateAround(id, now);
    return StartOutcome(
      mode: mode,
      entryId: id,
      activityName: activity.name,
      stoppedActivityName: stoppedName,
      undo: _undoToken(
        mode == StartMode.replacedMisstart
            ? 'Started ${activity.name}'
            : 'Switched to ${activity.name}',
        snapshots: before,
        createdIds: <String>[id],
      ),
    );
  }

  // ---------------------------------------------------------------- stopping

  /// Stops the running entry at exactly now (SPEC §6.2).
  ///
  /// A sub-minute span is kept as-is and reported via [StopOutcome.wasVeryShort]
  /// so the UI can offer "Discard"; it is never silently rounded up, which would
  /// record time that did not happen.
  Future<StopOutcome> stop() async => _db.transaction(() async {
    final runningRow = await _db.runningEntry().getSingleOrNull();
    if (runningRow == null) return const StopOutcome.nothingRunning();
    final running = runningRow.toDomain();
    final now = _clock.nowUtc();
    if (!now.isAfter(running.startUtc)) {
      // Clock went backwards; the UI offers "Fix start time" instead (SPEC §9.2).
      throw const InvariantViolation(
        'positiveDuration',
        'now is not after the running entry start (clock jumped backwards)',
      );
    }
    await _setEnd(running.id, now);
    await _validateAround(running.id, now);
    final activity = await _requireActivity(running.activityId);
    return StopOutcome(
      stopped: true,
      entryId: running.id,
      activityName: activity.name,
      duration: now.difference(running.startUtc),
      undo: _undoToken(
        'Stopped ${activity.name}',
        snapshots: <TimeEntryRow>[runningRow],
      ),
    );
  });

  /// Continue: reopen the most recent entry instead of creating an adjacent
  /// duplicate (SPEC §6.4).
  Future<UndoToken> continueEntry(
    String entryId, {
    required Duration window,
  }) async => _db.transaction(() async {
    final now = _clock.nowUtc();
    final row = await _requireRow(entryId);
    final entry = row.toDomain();
    final lastFinished = (await _db.lastFinishedEntry().getSingleOrNull())
        ?.toDomain();
    final running = (await _db.runningEntry().getSingleOrNull())?.toDomain();
    if (!canContinueEntry(
      entry: entry,
      lastFinished: lastFinished,
      running: running,
      now: now,
      window: window,
    )) {
      throw const InvariantViolation(
        'continueNotAllowed',
        'this entry is no longer the most recent, or something is running',
      );
    }
    await (_db.update(
      _db.timeEntries,
    )..where((t) => t.id.equals(entryId))).write(
      TimeEntriesCompanion(
        endUtc: const Value(null),
        updatedAt: Value(toMillis(now)),
      ),
    );
    await _validateAround(entryId, now);
    final activity = await _requireActivity(entry.activityId);
    return _undoToken(
      'Continued ${activity.name}',
      snapshots: <TimeEntryRow>[row],
    );
  });

  // ----------------------------------------------------------------- editing

  /// Moves one boundary, applying the whole of SPEC §7 via
  /// [resolveBoundaryMove]. A boundary shared with a neighbour moves both edges.
  Future<MoveOutcome> moveBoundary({
    required String entryId,
    required BoundaryEdge edge,
    required DateTime desired,
    required Duration snap,
  }) async => _db.transaction(() async {
    final now = _clock.nowUtc();
    final targetRow = await _requireRow(entryId);
    final target = targetRow.toDomain();
    final prevRow = await _db
        .entryEndingAtOrBefore(entryId, toMillis(target.startUtc))
        .getSingleOrNull();
    final nextRow = await _db
        .entryStartingAfter(entryId, toMillis(target.startUtc))
        .getSingleOrNull();

    final move = resolveBoundaryMove(
      target: target,
      edge: edge,
      desired: desired,
      prev: prevRow?.toDomain(),
      next: nextRow?.toDomain(),
      snap: snap,
      now: now,
    );

    final snapshots = <TimeEntryRow>[
      targetRow,
      if (move.neighbour != null)
        (move.neighbour!.id == prevRow?.id ? prevRow! : nextRow!),
    ];
    for (final entry in move.changedEntries) {
      await _writeTimes(entry, now);
    }
    await _validateAround(entryId, now);
    return MoveOutcome(
      wasClamped: move.wasClamped,
      appliedUtc: move.applied,
      undo: _undoToken('Moved boundary', snapshots: snapshots),
    );
  });

  /// Sets both edges at once, for typed input in the entry sheet (SPEC §8.4).
  ///
  /// Typed values are not snapped (SPEC §7.3) and a conflict is reported rather
  /// than silently clamped (SPEC §7.2).
  Future<UndoToken> setEntryTimes({
    required String entryId,
    required DateTime startUtc,
    DateTime? endUtc,
  }) async => _db.transaction(() async {
    final now = _clock.nowUtc();
    final row = await _requireRow(entryId);
    final updated = row.toDomain().copyWith(
      startUtc: startUtc,
      endUtc: endUtc,
      clearEnd: endUtc == null,
    );
    await _writeTimes(updated, now);
    await _validateAround(entryId, now);
    return _undoToken('Changed times', snapshots: <TimeEntryRow>[row]);
  });

  /// Splits one entry in two at [atUtc], both halves keeping the activity and
  /// note (SPEC §6.6).
  Future<UndoToken> split({
    required String entryId,
    required DateTime atUtc,
  }) async {
    final zone = await _zone();
    return _db.transaction(() async {
      final now = _clock.nowUtc();
      final row = await _requireRow(entryId);
      final entry = row.toDomain();
      final at = atUtc.toUtc();
      if (!at.isAfter(entry.startUtc) ||
          (entry.endUtc != null && !entry.endUtc!.isAfter(at))) {
        throw const InvariantViolation(
          'positiveDuration',
          'the split instant must fall strictly inside the entry',
        );
      }
      final newId = _ids.next();
      await _writeTimes(entry.copyWith(endUtc: at), now);
      await _db
          .into(_db.timeEntries)
          .insert(
            TimeEntriesCompanion.insert(
              id: newId,
              activityId: entry.activityId,
              note: Value(entry.note),
              startUtc: toMillis(at),
              endUtc: Value(
                entry.endUtc == null ? null : toMillis(entry.endUtc!),
              ),
              tzName: zone,
              createdAt: toMillis(now),
              updatedAt: toMillis(now),
            ),
          );
      await _validateAround(newId, now);
      return _undoToken(
        'Split entry',
        snapshots: <TimeEntryRow>[row],
        createdIds: <String>[newId],
      );
    });
  }

  /// Soft delete. The gap it leaves is data, not an error: neighbours are never
  /// stretched to cover it (SPEC §4.7, §6.8).
  Future<UndoToken> delete(String entryId) async => _db.transaction(() async {
    final now = _clock.nowUtc();
    final row = await _requireRow(entryId);
    await _softDelete(entryId, now);
    return _undoToken('Deleted entry', snapshots: <TimeEntryRow>[row]);
  });

  // ------------------------------------------------------------- activities

  Future<Activity> renameActivity({
    required String activityId,
    required String name,
  }) async {
    if (!Activity.isValidName(name)) {
      throw ArgumentError.value(name, 'name', 'not a usable activity name');
    }
    return _db.transaction(() async {
      final now = _clock.nowUtc();
      final key = Activity.keyFor(name);
      final existing = await (_db.select(
        _db.activities,
      )..where((t) => t.nameKey.equals(key))).getSingleOrNull();

      if (existing != null && existing.id != activityId) {
        // Merging: re-point every entry, then drop the now-empty activity
        // (SPEC §6.7).
        await (_db.update(
          _db.timeEntries,
        )..where((t) => t.activityId.equals(activityId))).write(
          TimeEntriesCompanion(
            activityId: Value(existing.id),
            updatedAt: Value(toMillis(now)),
          ),
        );
        await (_db.delete(
          _db.activities,
        )..where((t) => t.id.equals(activityId))).go();
        return existing.toDomain();
      }

      await (_db.update(
        _db.activities,
      )..where((t) => t.id.equals(activityId))).write(
        ActivitiesCompanion(
          name: Value(name.trim()),
          nameKey: Value(key),
          updatedAt: Value(toMillis(now)),
        ),
      );
      return (await _requireActivity(activityId)).copyWith(name: name.trim());
    });
  }

  Future<void> setActivityColor({
    required String activityId,
    required int colorSeed,
  }) async {
    final now = _clock.nowUtc();
    await (_db.update(
      _db.activities,
    )..where((t) => t.id.equals(activityId))).write(
      ActivitiesCompanion(
        colorSeed: Value(colorSeed),
        updatedAt: Value(toMillis(now)),
      ),
    );
  }

  // ----------------------------------------------------------------- helpers

  Future<Activity> _findOrCreateActivity(String name) async {
    final key = Activity.keyFor(name);
    final existing = await (_db.select(
      _db.activities,
    )..where((t) => t.nameKey.equals(key))).getSingleOrNull();
    if (existing != null) return existing.toDomain();

    final now = _clock.nowUtc();
    final usedSeeds = await _db
        .select(_db.activities)
        .map((row) => row.colorSeed)
        .get();
    final activity = Activity(
      id: _ids.next(),
      name: name.trim(),
      colorSeed: Activity.nextColorSeed(usedSeeds),
    );
    await _db
        .into(_db.activities)
        .insert(
          ActivitiesCompanion.insert(
            id: activity.id,
            name: activity.name,
            nameKey: key,
            colorSeed: activity.colorSeed,
            createdAt: toMillis(now),
            updatedAt: toMillis(now),
          ),
        );
    return activity;
  }

  Future<void> _setEnd(String entryId, DateTime end) =>
      (_db.update(_db.timeEntries)..where((t) => t.id.equals(entryId))).write(
        TimeEntriesCompanion(
          endUtc: Value(toMillis(end)),
          updatedAt: Value(toMillis(end)),
        ),
      );

  Future<void> _writeTimes(TimeEntry entry, DateTime now) =>
      (_db.update(_db.timeEntries)..where((t) => t.id.equals(entry.id))).write(
        TimeEntriesCompanion(
          startUtc: Value(toMillis(entry.startUtc)),
          endUtc: Value(entry.endUtc == null ? null : toMillis(entry.endUtc!)),
          updatedAt: Value(toMillis(now)),
        ),
      );

  Future<void> _softDelete(String entryId, DateTime now) =>
      (_db.update(_db.timeEntries)..where((t) => t.id.equals(entryId))).write(
        TimeEntriesCompanion(
          deletedAt: Value(toMillis(now)),
          updatedAt: Value(toMillis(now)),
        ),
      );

  Future<TimeEntryRow> _requireRow(String entryId) async {
    final row =
        await (_db.select(_db.timeEntries)
              ..where((t) => t.id.equals(entryId) & t.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) {
      throw StateError('no live entry with id $entryId');
    }
    return row;
  }

  Future<TimeEntry> _requireEntry(String entryId) async =>
      (await _requireRow(entryId)).toDomain();

  Future<Activity> _requireActivity(String activityId) async {
    final row = await (_db.select(
      _db.activities,
    )..where((t) => t.id.equals(activityId))).getSingleOrNull();
    if (row == null) throw StateError('no activity with id $activityId');
    return row.toDomain();
  }

  /// Re-reads the touched entry and its immediate neighbours and asserts SPEC §4
  /// over them. Called inside the transaction, so a violation rolls everything
  /// back instead of leaving an invalid timeline.
  Future<void> _validateAround(String entryId, DateTime now) async {
    final entry = await _requireEntry(entryId);
    final prev = await _db
        .entryEndingAtOrBefore(entryId, toMillis(entry.startUtc))
        .getSingleOrNull();
    final next = await _db
        .entryStartingAfter(entryId, toMillis(entry.startUtc))
        .getSingleOrNull();
    final running = await _db.runningEntry().get();
    checkNeighbourhood(<TimeEntry>[
      entry,
      ?prev?.toDomain(),
      ?next?.toDomain(),
      ...running.map((r) => r.toDomain()).where((r) => r.id != entry.id),
    ], now: now);
  }

  /// Writes [row] back exactly as it was, nulls included.
  ///
  /// Deliberately not `insertOnConflictUpdate`: drift omits null columns from
  /// the DO UPDATE branch of an upsert, so it can never put `end_utc` *back* to
  /// null -- which is precisely what undoing a stop has to do.
  Future<void> _restoreRow(TimeEntryRow row) async {
    final restored = TimeEntriesCompanion(
      id: Value(row.id),
      activityId: Value(row.activityId),
      note: Value(row.note),
      startUtc: Value(row.startUtc),
      endUtc: Value(row.endUtc),
      tzName: Value(row.tzName),
      createdAt: Value(row.createdAt),
      updatedAt: Value(row.updatedAt),
      deletedAt: Value(row.deletedAt),
    );
    final affected = await (_db.update(
      _db.timeEntries,
    )..where((t) => t.id.equals(row.id))).write(restored);
    if (affected == 0) await _db.into(_db.timeEntries).insert(restored);
  }

  /// Builds an undo that restores the exact rows that were touched and removes
  /// the ones that were created.
  ///
  /// Restoring snapshots last-running-first matters: putting a running entry
  /// back while another still holds the running slot would trip the unique
  /// index, so created rows are removed first.
  UndoToken _undoToken(
    String description, {
    required List<TimeEntryRow> snapshots,
    List<String> createdIds = const <String>[],
  }) => UndoToken(description, () async {
    await _db.transaction(() async {
      for (final id in createdIds) {
        await (_db.delete(_db.timeEntries)..where((t) => t.id.equals(id))).go();
      }
      final ordered = snapshots.toList()
        ..sort((a, b) {
          final aRunning = a.endUtc == null && a.deletedAt == null;
          final bRunning = b.endUtc == null && b.deletedAt == null;
          if (aRunning == bRunning) return 0;
          return aRunning ? 1 : -1;
        });
      for (final row in ordered) {
        await _restoreRow(row);
      }
    });
  });
}
