import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/core/clock.dart';
import 'package:time_log/src/core/ids.dart';
import 'package:time_log/src/core/time_zone.dart';
import 'package:time_log/src/data/db/database.dart';
import 'package:time_log/src/data/repositories/active_session_repository.dart';
import 'package:time_log/src/domain/presence/active_session.dart';
import 'package:time_log/src/domain/presence/presence_rules.dart';
import 'package:time_log/src/domain/timeline_writer.dart';

/// SPEC §9.9 against real SQLite.
void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ActiveSessionRepository sessions;
  final t0 = DateTime.utc(2026, 3, 10, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(t0);
    sessions = ActiveSessionRepository(
      db: db,
      clock: clock,
      ids: SequentialIdGenerator('s'),
      timeZone: const FixedTimeZoneResolver('Europe/Berlin'),
    );
  });
  tearDown(() => db.close());

  Future<List<ActiveSession>> all() =>
      sessions.watchRange(DateTime.utc(2026), DateTime.utc(2027)).first;

  /// A signal now, as the platform would send it.
  Future<void> unlock() =>
      sessions.apply(PresenceSignal.active(clock.nowUtc()));

  Future<void> lock() => sessions.apply(
    PresenceSignal.inactive(SessionEndReason.lock, clock.nowUtc()),
  );

  /// Time passing with the app alive, so heartbeats arrive. Skipping them would
  /// look like a crash, and the session would rightly be treated as lost.
  Future<void> stayActive(Duration length) async {
    for (var i = 0; i < length.inMinutes; i++) {
      clock.advance(const Duration(minutes: 1));
      await sessions.heartbeat();
    }
  }

  test('a day of signals becomes sessions', () async {
    await unlock();
    await stayActive(const Duration(hours: 2));
    await lock();
    clock.advance(const Duration(hours: 1));
    await unlock();
    await stayActive(const Duration(hours: 1));
    await lock();

    final stored = await all();
    expect(stored, hasLength(2));
    expect(stored.first.endUtc, t0.add(const Duration(hours: 2)));
    expect(stored.first.endReason, SessionEndReason.lock);
    expect(stored.first.tzName, 'Europe/Berlin');
    expect(stored.last.startUtc, t0.add(const Duration(hours: 3)));
  });

  test('watchRange keeps only sessions that touch the window', () async {
    await unlock();
    await stayActive(const Duration(hours: 1));
    await lock();

    expect(
      await sessions
          .watchRange(
            t0.add(const Duration(hours: 1)),
            t0.add(const Duration(hours: 2)),
          )
          .first,
      isEmpty,
    );
    expect(
      await sessions
          .watchRange(
            t0.add(const Duration(minutes: 30)),
            t0.add(const Duration(hours: 2)),
          )
          .first,
      hasLength(1),
    );
  });

  test('onlyOneOpenSessionEverExists', () async {
    await sessions.apply(PresenceSignal.active(t0));
    await expectLater(
      db.customStatement(
        'INSERT INTO active_sessions (id, start_utc, last_seen_utc, tz_name, '
        "created_at, updated_at) VALUES ('x', 5, 5, 'UTC', 1, 1)",
      ),
      throwsA(anything),
    );
  });

  test('a session cannot end before it starts', () async {
    await expectLater(
      db.customStatement(
        'INSERT INTO active_sessions (id, start_utc, end_utc, last_seen_utc, '
        "tz_name, created_at, updated_at) VALUES ('x', 5, 5, 5, 'UTC', 1, 1)",
      ),
      throwsA(anything),
    );
  });

  test('a short break carries the same session on', () async {
    await unlock();
    await stayActive(const Duration(hours: 1));
    await lock();
    clock.advance(const Duration(seconds: 10));
    await unlock();

    final stored = await all();
    expect(stored, hasLength(1));
    expect(stored.single.startUtc, t0);
    expect(stored.single.isOpen, isTrue);
    expect(stored.single.endReason, isNull);
  });

  test('the heartbeat stamps the open session', () async {
    await sessions.apply(PresenceSignal.active(t0));
    clock.advance(const Duration(minutes: 1));
    await sessions.heartbeat();

    expect((await sessions.open())!.lastSeenUtc, clock.nowUtc());
  });

  test('a heartbeat after a long silence ends it at last seen', () async {
    await sessions.apply(PresenceSignal.active(t0));
    clock.advance(const Duration(minutes: 1));
    await sessions.heartbeat();
    final lastSeen = clock.nowUtc();
    clock.advance(const Duration(hours: 5));
    await sessions.heartbeat();

    final stored = (await all()).single;
    expect(stored.endUtc, lastSeen);
    expect(stored.endReason, SessionEndReason.lost);
  });

  test('stop closes with reason off, and deleteAll clears it all', () async {
    await sessions.apply(PresenceSignal.active(t0));
    clock.advance(const Duration(minutes: 1));
    await sessions.stop();
    expect((await all()).single.endReason, SessionEndReason.off);

    await sessions.deleteAll();
    expect(await all(), isEmpty);
  });

  test('logging a span adds an entry and keeps the session', () async {
    final writer = TimelineWriter(
      db: db,
      clock: clock,
      ids: SequentialIdGenerator('e'),
      timeZone: const FixedTimeZoneResolver('Europe/Berlin'),
    );
    await unlock();
    await stayActive(const Duration(hours: 1));
    await lock();
    clock.advance(const Duration(hours: 2));
    final before = await all();
    expect(before, hasLength(1));

    final undo = await writer.insertEntry(
      name: 'Writing specs',
      startUtc: t0,
      endUtc: t0.add(const Duration(hours: 1)),
    );

    expect(await db.select(db.timeEntries).get(), hasLength(1));
    expect(await all(), before);

    await undo.undo();
    expect(
      (await db.select(db.timeEntries).get()).where((e) => e.deletedAt == null),
      isEmpty,
    );
    expect(await all(), before);
  });

  test('deleteAllData takes sessions with it', () async {
    final writer = TimelineWriter(
      db: db,
      clock: clock,
      ids: SequentialIdGenerator('e'),
      timeZone: const FixedTimeZoneResolver('Europe/Berlin'),
    );
    await sessions.apply(PresenceSignal.active(t0));
    await writer.deleteAllData();
    expect(await all(), isEmpty);
  });
}
