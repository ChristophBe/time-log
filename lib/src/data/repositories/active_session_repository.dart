import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/time_zone.dart';
import '../../domain/backup/json_backup.dart';
import '../../domain/presence/active_session.dart';
import '../../domain/presence/presence_rules.dart';
import '../db/database.dart';
import '../db/database_provider.dart';
import '../db/mappers.dart';

part 'active_session_repository.g.dart';

/// The only code that writes to `active_sessions`, as `TimelineWriter` is for
/// `time_entries` (SPEC §9.9). Each write is one transaction; what to do comes
/// from the pure rules in `domain/presence/`.
class ActiveSessionRepository {
  const ActiveSessionRepository({
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

  /// Sessions overlapping `[from, to)`, oldest first.
  Stream<List<ActiveSession>> watchRange(DateTime from, DateTime to) => _db
      .sessionsInRange(toMillis(to), toMillis(from))
      .watch()
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  Future<ActiveSession?> open() async =>
      (await _db.openSession().getSingleOrNull())?.toDomain();

  Future<List<BackupSession>> readForBackup() async {
    final rows = await _db.select(_db.activeSessions).get();
    return rows.map((row) => row.toBackup()).toList();
  }

  /// Records what the platform said.
  Future<void> apply(PresenceSignal signal) => _db.transaction(() async {
    final open = await this.open();
    final lastClosed = await _db.lastClosedSession().getSingleOrNull();
    await _write(
      decide(open: open, lastClosed: lastClosed?.toDomain(), signal: signal),
    );
  });

  /// Stamps the open session, or ends it if the app has been gone too long.
  Future<void> heartbeat() => _db.transaction(() async {
    final open = await this.open();
    if (open == null) return;
    final now = _clock.nowUtc();
    final settled = settle(open: open, now: now);
    if (settled != null) return _write(<SessionChange>[settled]);
    if (!now.isAfter(open.lastSeenUtc)) return;
    await (_db.update(
      _db.activeSessions,
    )..where((t) => t.id.equals(open.id))).write(
      ActiveSessionsCompanion(
        lastSeenUtc: Value(toMillis(now)),
        updatedAt: Value(toMillis(now)),
      ),
    );
  });

  /// Tracking was turned off.
  Future<void> stop() =>
      apply(PresenceSignal.inactive(SessionEndReason.off, _clock.nowUtc()));

  Future<void> deleteAll() => _db.delete(_db.activeSessions).go();

  Future<void> _write(List<SessionChange> changes) async {
    final now = toMillis(_clock.nowUtc());
    for (final change in changes) {
      switch (change) {
        case OpenSession(:final atUtc):
          await _db
              .into(_db.activeSessions)
              .insert(
                ActiveSessionsCompanion.insert(
                  id: _ids.next(),
                  startUtc: toMillis(atUtc),
                  lastSeenUtc: toMillis(atUtc),
                  tzName: await _timeZone.currentZone(),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        case ReopenSession(:final id, :final atUtc):
          await _update(
            id,
            ActiveSessionsCompanion(
              endUtc: const Value(null),
              endReason: const Value(null),
              lastSeenUtc: Value(toMillis(atUtc)),
              updatedAt: Value(now),
            ),
          );
        case CloseSession(:final id, :final atUtc, :final reason):
          await _update(
            id,
            ActiveSessionsCompanion(
              endUtc: Value(toMillis(atUtc)),
              endReason: Value(reason.name),
              updatedAt: Value(now),
            ),
          );
        case DropSession(:final id):
          await (_db.delete(
            _db.activeSessions,
          )..where((t) => t.id.equals(id))).go();
      }
    }
  }

  Future<void> _update(String id, ActiveSessionsCompanion values) =>
      (_db.update(
        _db.activeSessions,
      )..where((t) => t.id.equals(id))).write(values);
}

@Riverpod(keepAlive: true)
ActiveSessionRepository activeSessionRepository(Ref ref) =>
    ActiveSessionRepository(
      db: ref.watch(appDatabaseProvider),
      clock: ref.watch(appClockProvider),
      ids: ref.watch(idGeneratorProvider),
      timeZone: ref.watch(timeZoneResolverProvider),
    );
