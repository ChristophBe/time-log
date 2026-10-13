import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../core/time_zone.dart';
import '../data/db/database.dart';
import '../data/db/database_provider.dart';
import '../data/db/mappers.dart';
import 'backup/json_backup.dart';
import 'models/activity.dart';
import 'models/time_entry.dart';
import 'timeline/continue_rule.dart';
import 'timeline/day_rollover.dart';
import 'timeline/day_window.dart';
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

/// What one SPEC §6.11 rollover pass did.
class RolloverOutcome {
  const RolloverOutcome({
    required this.boundaries,
    required this.runningEntryId,
  });

  const RolloverOutcome.nothingToDo()
    : boundaries = const <DateTime>[],
      runningEntryId = null;

  /// The midnights that were cut at, oldest first.
  final List<DateTime> boundaries;

  /// The entry left running, or null when nothing was running to begin with or
  /// the run was too old to restart (SPEC §6.11).
  final String? runningEntryId;

  bool get changedAnything => boundaries.isNotEmpty;
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

  // ----------------------------------------------------------- day rollover

  /// Stops the running entry at every local midnight it has crossed and
  /// restarts it there, so no running entry ever spans a day (SPEC §6.11).
  ///
  /// Safe to call whenever: it writes nothing when nothing is running and
  /// nothing when no boundary has been crossed, and running it twice does what
  /// running it once did. That is what lets it be a catch-up pass at launch, on
  /// resume and on the tick (SPEC §9.3) instead of an alarm set for 00:00 --
  /// which §4.5 rules out anyway, since a midnight has to be in the past before
  /// it can be written as an end.
  ///
  /// The one method here that returns no [UndoToken]. Every other one does
  /// because a person pressed something; this one runs by itself, and an Undo
  /// button appearing unprompted at midnight would be noise. Both halves are
  /// ordinary entries afterwards and can be edited like any others.
  Future<RolloverOutcome> rollOverRunningEntry({
    required DayWindowCalculator days,
  }) async {
    final zone = await _zone();
    return _db.transaction(() async {
      final runningRow = await _db.runningEntry().getSingleOrNull();
      if (runningRow == null) return const RolloverOutcome.nothingToDo();
      final now = _clock.nowUtc();
      final running = runningRow.toDomain();
      final plan = planDayRollover(
        startUtc: running.startUtc,
        now: now,
        days: days,
      );
      if (plan.isEmpty) return const RolloverOutcome.nothingToDo();

      var current = running;
      for (final boundary in plan.boundaries) {
        // `_setEnd` would stamp `updatedAt` with the end instant, which is
        // right for a stop happening now and wrong for a cut made after the
        // fact: the row is being touched now, at a boundary already past.
        await _writeTimes(current.copyWith(endUtc: boundary), now);
        // An abandoned run is closed and not picked back up (SPEC §6.11).
        if (plan.abandoned) break;

        // Closed before the next one is opened, every time: the single-running
        // rule is a unique index over a generated column (SPEC §5.2), so two
        // open rows for even an instant trip it. `_start` relies on the same
        // ordering.
        final id = _ids.next();
        await _db
            .into(_db.timeEntries)
            .insert(
              TimeEntriesCompanion.insert(
                id: id,
                activityId: current.activityId,
                note: Value(current.note),
                startUtc: toMillis(boundary),
                endUtc: const Value(null),
                tzName: zone,
                createdAt: toMillis(now),
                updatedAt: toMillis(now),
              ),
            );
        current = TimeEntry(
          id: id,
          activityId: current.activityId,
          startUtc: boundary,
          endUtc: null,
          tzName: zone,
          note: current.note,
        );
      }

      // The final entry is the one worth re-checking: its start is the last
      // boundary written and its predecessor is the stub before it. The run's
      // own start never moved, and an end that moved *earlier* cannot have
      // grown into anything.
      await _validateAround(current.id, now);
      return RolloverOutcome(
        boundaries: plan.boundaries,
        runningEntryId: plan.abandoned ? null : current.id,
      );
    });
  }

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
  /// than silently clamped (SPEC §7.2). A boundary that was *shared* with a
  /// neighbour still moves both edges, exactly as dragging it does (SPEC §7.1) --
  /// otherwise typing could never move a shared boundary at all, since any value
  /// would overlap the neighbour.
  Future<UndoToken> setEntryTimes({
    required String entryId,
    required DateTime startUtc,
    DateTime? endUtc,
  }) async => _db.transaction(() async {
    final now = _clock.nowUtc();
    final row = await _requireRow(entryId);
    final entry = row.toDomain();

    final prevRow = await _db
        .entryEndingAtOrBefore(entryId, toMillis(entry.startUtc))
        .getSingleOrNull();
    final nextRow = await _db
        .entryStartingAfter(entryId, toMillis(entry.startUtc))
        .getSingleOrNull();
    final prev = prevRow?.toDomain();
    final next = nextRow?.toDomain();

    final movesStart = startUtc != entry.startUtc;
    final movesEnd = endUtc != entry.endUtc;
    final sharedPrev =
        movesStart && prev != null && prev.endUtc == entry.startUtc;
    final sharedNext =
        movesEnd && next != null && next.startUtc == entry.endUtc;

    final snapshots = <TimeEntryRow>[
      row,
      if (sharedPrev) prevRow!,
      if (sharedNext) nextRow!,
    ];

    await _writeTimes(
      entry.copyWith(
        startUtc: startUtc,
        endUtc: endUtc,
        clearEnd: endUtc == null,
      ),
      now,
    );
    if (sharedPrev) {
      await _writeTimes(prev.copyWith(endUtc: startUtc), now);
    }
    if (sharedNext && endUtc != null) {
      await _writeTimes(next.copyWith(startUtc: endUtc), now);
    }

    await _validateAround(entryId, now);
    if (sharedPrev) await _validateAround(prev.id, now);
    if (sharedNext) await _validateAround(next.id, now);

    return _undoToken('Changed times', snapshots: snapshots);
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

  /// Edits an entry's note (SPEC §8.4).
  ///
  /// The only entry field that does not touch the timeline, so unlike every
  /// other method here it reads no neighbourhood and re-checks no SPEC §4
  /// invariant: there is nothing a note can make invalid.
  ///
  /// An empty or whitespace-only note is stored as null rather than as "", so
  /// "has a note" is one question and not two.
  Future<UndoToken> setEntryNote({
    required String entryId,
    required String? note,
  }) async => _db.transaction(() async {
    final trimmed = note?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (value != null && value.length > TimeEntry.maxNoteLength) {
      throw ArgumentError.value(
        note,
        'note',
        'longer than ${TimeEntry.maxNoteLength} characters',
      );
    }
    final now = _clock.nowUtc();
    final row = await _requireRow(entryId);
    await (_db.update(
      _db.timeEntries,
    )..where((t) => t.id.equals(entryId))).write(
      TimeEntriesCompanion(note: Value(value), updatedAt: Value(toMillis(now))),
    );
    return _undoToken('Note changed', snapshots: <TimeEntryRow>[row]);
  });

  /// Re-points one entry at a different activity, creating it if the name is
  /// new (SPEC §6.10).
  ///
  /// The retro-labelling action: it moves nothing on the timeline, so like
  /// [setEntryNote] it reads no neighbourhood and re-checks no SPEC §4
  /// invariant. An activity id is not an instant and is not the running slot,
  /// so there is nothing it can invalidate -- which is also why it is legal on
  /// the running entry.
  ///
  /// A null [UndoToken] means the entry already had that activity and nothing
  /// was written, the no-op of SPEC §6.1 in a different key.
  Future<({Activity activity, UndoToken? undo})> setEntryActivity({
    required String entryId,
    required String name,
  }) async {
    if (!Activity.isValidName(name)) {
      throw ArgumentError.value(name, 'name', 'not a usable activity name');
    }
    return _db.transaction(() async {
      final now = _clock.nowUtc();
      final row = await _requireRow(entryId);
      // Asked before resolving, so the undo knows whether this call is what
      // brought the activity into existence.
      final existed = await _findActivityByKey(Activity.keyFor(name)) != null;
      final activity = await _findOrCreateActivity(name);
      if (activity.id == row.activityId) {
        return (activity: activity, undo: null);
      }

      await (_db.update(
        _db.timeEntries,
      )..where((t) => t.id.equals(entryId))).write(
        TimeEntriesCompanion(
          activityId: Value(activity.id),
          updatedAt: Value(toMillis(now)),
        ),
      );

      final entryUndo = _undoToken(
        'Activity changed',
        snapshots: <TimeEntryRow>[row],
      );
      // Undoing a relabel that created an activity has to take the activity
      // back out too, or the timeline returns to how it was while the activity
      // list does not.
      final created = existed ? null : activity.id;
      return (
        activity: activity,
        undo: UndoToken('Activity changed', () async {
          await entryUndo.undo();
          if (created != null) await _deleteActivityIfUnused(created);
        }),
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

  /// Fills a gap with a new entry covering exactly `[startUtc, endUtc)`
  /// (SPEC §8.2).
  ///
  /// Not a variant of start: nothing begins now, nothing is stopped, and the
  /// running entry is left alone. It is the one way to add time that already
  /// passed, which is why it is checked against §4 like everything else rather
  /// than trusted to be in a gap because the UI said so.
  Future<UndoToken> insertEntry({
    required String name,
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    if (!Activity.isValidName(name)) {
      throw ArgumentError.value(name, 'name', 'not a usable activity name');
    }
    return _db.transaction(() async {
      final now = _clock.nowUtc();
      if (!endUtc.isAfter(startUtc)) {
        throw const InvariantViolation(
          'positiveDuration',
          'An entry has to end after it starts.',
        );
      }
      if (startUtc.isAfter(now)) {
        throw const InvariantViolation(
          'noFutureStarts',
          'An entry cannot start in the future.',
        );
      }

      final activity = await _findOrCreateActivity(name);
      final id = _ids.next();
      await _db
          .into(_db.timeEntries)
          .insert(
            TimeEntriesCompanion.insert(
              id: id,
              activityId: activity.id,
              startUtc: toMillis(startUtc),
              endUtc: Value(toMillis(endUtc)),
              tzName: await _zone(),
              createdAt: toMillis(now),
              updatedAt: toMillis(now),
            ),
          );
      await _validateAround(id, now);
      return _undoToken(
        'Added entry',
        snapshots: const <TimeEntryRow>[],
        createdIds: <String>[id],
      );
    });
  }

  // ----------------------------------------------------------------- backup

  /// Applies a merge plan, or nothing at all (SPEC §8.6, §4.6).
  ///
  /// One transaction for the whole file: an import that failed halfway would
  /// leave a timeline that is neither the old one nor the new one, and §4.6
  /// does not make an exception for imports. A plan that was rejected by
  /// `planMerge` is refused here too rather than trusted to have been checked
  /// by the UI.
  Future<void> applyBackup(BackupPlan plan) async {
    if (!plan.isApplicable) {
      throw InvariantViolation('importWouldBreakTimeline', plan.rejection!);
    }
    await _db.transaction(() async {
      // Deleted wholesale rather than upserted row by row: the plan already
      // contains the merged result, so anything still here that is not in it
      // was removed by the merge.
      await _db.delete(_db.timeEntries).go();
      await _db.delete(_db.activities).go();

      for (final activity in plan.activitiesToWrite) {
        await _db
            .into(_db.activities)
            .insert(
              ActivitiesCompanion.insert(
                id: activity.id,
                name: activity.name,
                nameKey: activity.nameKey,
                colorSeed: activity.colorSeed,
                archived: Value(activity.archived ? 1 : 0),
                createdAt: toMillis(activity.createdAt),
                updatedAt: toMillis(activity.updatedAt),
              ),
            );
      }
      for (final entry in plan.entriesToWrite) {
        await _db
            .into(_db.timeEntries)
            .insert(
              TimeEntriesCompanion.insert(
                id: entry.id,
                activityId: entry.activityId,
                note: Value(entry.note),
                startUtc: toMillis(entry.startUtc),
                endUtc: Value(
                  entry.endUtc == null ? null : toMillis(entry.endUtc!),
                ),
                tzName: entry.tzName,
                createdAt: toMillis(entry.createdAt),
                updatedAt: toMillis(entry.updatedAt),
                deletedAt: Value(
                  entry.deletedAt == null ? null : toMillis(entry.deletedAt!),
                ),
              ),
            );
      }
    });
  }

  /// Everything, gone (SPEC §8.6). Not undoable, which is why the UI asks you
  /// to type the word first.
  Future<void> deleteAllData() => _db.transaction(() async {
    await _db.delete(_db.timeEntries).go();
    await _db.delete(_db.activities).go();
  });

  // ------------------------------------------------------------- activities

  /// Renames, or merges when the name is already taken (SPEC §6.7).
  ///
  /// Returns an undo token, because §6.7 says both of these are undoable — and
  /// a merge is the least reversible thing in the app: it re-points every entry
  /// of one activity onto another and then drops the empty one.
  Future<({Activity activity, UndoToken undo})> renameActivity({
    required String activityId,
    required String name,
  }) async {
    if (!Activity.isValidName(name)) {
      throw ArgumentError.value(name, 'name', 'not a usable activity name');
    }
    return _db.transaction(() async {
      final now = _clock.nowUtc();
      final key = Activity.keyFor(name);
      final before = await (_db.select(
        _db.activities,
      )..where((t) => t.id.equals(activityId))).getSingle();
      final existing = await (_db.select(
        _db.activities,
      )..where((t) => t.nameKey.equals(key))).getSingleOrNull();

      if (existing != null && existing.id != activityId) {
        // Merging: re-point every entry, then drop the now-empty activity
        // (SPEC §6.7). The ids are read first so the undo knows which entries
        // to put back — the ones that moved, not every entry of the target.
        final moved = await (_db.select(
          _db.timeEntries,
        )..where((t) => t.activityId.equals(activityId))).get();
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

        return (
          activity: existing.toDomain(),
          undo: UndoToken('Merged ${before.name}', () async {
            await _db.transaction(() async {
              await _db.into(_db.activities).insert(before);
              for (final row in moved) {
                await (_db.update(
                  _db.timeEntries,
                )..where((t) => t.id.equals(row.id))).write(
                  TimeEntriesCompanion(
                    activityId: Value(row.activityId),
                    updatedAt: Value(row.updatedAt),
                  ),
                );
              }
            });
          }),
        );
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
      return (
        activity: (await _requireActivity(activityId))
            .copyWith(name: name.trim()),
        undo: UndoToken('Renamed ${before.name}', () async {
          await (_db.update(
            _db.activities,
          )..where((t) => t.id.equals(activityId))).write(
            ActivitiesCompanion(
              name: Value(before.name),
              nameKey: Value(before.nameKey),
              updatedAt: Value(before.updatedAt),
            ),
          );
        }),
      );
    });
  }

  /// Recolours an activity, undoably (SPEC §6.7).
  Future<UndoToken> setActivityColor({
    required String activityId,
    required int colorSeed,
  }) async {
    final now = _clock.nowUtc();
    final before = await (_db.select(
      _db.activities,
    )..where((t) => t.id.equals(activityId))).getSingle();
    await (_db.update(
      _db.activities,
    )..where((t) => t.id.equals(activityId))).write(
      ActivitiesCompanion(
        colorSeed: Value(colorSeed),
        updatedAt: Value(toMillis(now)),
      ),
    );
    return UndoToken('Recoloured ${before.name}', () async {
      await (_db.update(
        _db.activities,
      )..where((t) => t.id.equals(activityId))).write(
        ActivitiesCompanion(
          colorSeed: Value(before.colorSeed),
          updatedAt: Value(before.updatedAt),
        ),
      );
    });
  }

  // ----------------------------------------------------------------- helpers

  Future<ActivityRow?> _findActivityByKey(String key) => (_db.select(
    _db.activities,
  )..where((t) => t.nameKey.equals(key))).getSingleOrNull();

  Future<Activity> _findOrCreateActivity(String name) async {
    final key = Activity.keyFor(name);
    final existing = await _findActivityByKey(key);
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

  /// Drops an activity nothing points at any more.
  ///
  /// Checked rather than assumed: between a relabel and its undo the activity
  /// may have been used by something else, and dropping it then would break the
  /// `activity_id` foreign key.
  Future<void> _deleteActivityIfUnused(String activityId) async {
    final used = await (_db.select(
      _db.timeEntries,
    )..where((t) => t.activityId.equals(activityId))).get();
    if (used.isNotEmpty) return;
    await (_db.delete(
      _db.activities,
    )..where((t) => t.id.equals(activityId))).go();
  }

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
    // Keyed by id rather than concatenated, because the same row can arrive
    // twice: when `next` *is* the running entry it comes in as both. Two copies
    // of one running entry read as two running entries to §4.1, and as an
    // overlap to §4.2, which made correcting the last finished entry's
    // boundaries impossible while anything was running (SPEC §14.5).
    final neighbourhood = <String, TimeEntry>{
      for (final candidate in <TimeEntry>[
        entry,
        ?prev?.toDomain(),
        ?next?.toDomain(),
        ...running.map((r) => r.toDomain()),
      ])
        candidate.id: candidate,
    };
    checkNeighbourhood(neighbourhood.values, now: now);
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
