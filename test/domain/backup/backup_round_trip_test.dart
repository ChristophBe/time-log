import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/data/db/mappers.dart';
import 'package:time_log/src/domain/backup/json_backup.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/presence/active_session.dart';
import 'package:time_log/src/domain/timeline/invariants.dart';

import '../../support/fixtures.dart';

/// SPEC §14.10: "Full data export and re-import round-trips to an identical
/// timeline." This is that criterion, against a real database.
void main() {
  late TimelineHarness h;

  setUp(() => h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9)));
  tearDown(() => h.close());

  /// A day with a switch, a stop, a gap, a note and a deletion in it.
  Future<void> trackADay() async {
    await h.writer.startByName(name: 'Writing specs');
    h.clock.advance(const Duration(minutes: 90));
    await h.writer.startByName(name: 'Email');
    h.clock.advance(const Duration(minutes: 30));
    await h.writer.stop();
    h.clock.advance(const Duration(minutes: 20));
    await h.writer.startByName(name: 'Code review');
    h.clock.advance(const Duration(minutes: 45));
    await h.writer.stop();

    final entries = await h.entries();
    await h.writer.setEntryNote(entryId: entries.first.id, note: 'chapter 3');
    // And something deleted, so the tombstone has to survive too.
    h.clock.advance(const Duration(minutes: 5));
    await h.writer.startByName(name: 'Mistake');
    h.clock.advance(const Duration(minutes: 2));
    await h.writer.stop();
    final all = await h.entries();
    await h.writer.delete(all.last.id);
  }

  Future<String> exportAll() async {
    final data = await h.repository.readForBackup();
    return encodeBackup(
      projects: data.projects,
      activities: data.activities,
      entries: data.entries,
      settings: const AppSettings(),
      exportedAt: h.now,
    );
  }

  Future<void> importInto(String text) async {
    final read = parseBackup(text);
    final existing = await h.repository.readForBackup();
    final plan = planMerge(
      incoming: (read as BackupReadOk).file,
      existingEntries: existing.entries,
      existingActivities: existing.activities,
      existingProjects: existing.projects,
      now: h.now,
    );
    expect(plan.isApplicable, isTrue, reason: plan.rejection ?? '');
    await h.writer.applyBackup(plan);
  }

  /// Everything that matters about an entry, for comparison.
  List<String> fingerprint(List<TimeEntry> entries) => <String>[
    for (final entry in entries)
      '${entry.id}|${entry.activityId}|${entry.startUtc.toIso8601String()}'
          '|${entry.endUtc?.toIso8601String()}|${entry.note}|${entry.tzName}',
  ];

  test('export -> wipe -> import gives back the same timeline', () async {
    await trackADay();
    final before = fingerprint(await h.entries());
    final activitiesBefore = (await h.repository.watchActivitiesById().first)
        .values
        .map((a) => '${a.id}|${a.name}|${a.colorSeed}')
        .toList();
    final file = await exportAll();

    await h.writer.deleteAllData();
    expect(await h.entries(), isEmpty, reason: 'wiped');

    await importInto(file);

    expect(fingerprint(await h.entries()), before);
    expect(
      (await h.repository.watchActivitiesById().first).values
          .map((a) => '${a.id}|${a.name}|${a.colorSeed}')
          .toList(),
      activitiesBefore,
    );
  });

  test(
    'projects and the entries in them survive the round trip (SPEC §6.12)',
    () async {
      final client = (await h.writer.createProject('Client A')).project;
      final filed = await h.writer.startByName(
        name: 'Writing specs',
        projectId: client.id,
      );
      h.clock.advance(const Duration(hours: 1));
      await h.writer.startByName(name: 'Writing specs');
      h.clock.advance(const Duration(hours: 1));
      await h.writer.stop();
      final file = await exportAll();

      await h.writer.deleteAllData();
      expect(await h.repository.watchProjectsById().first, isEmpty);
      await importInto(file);

      expect(await h.repository.watchProjectsById().first, <String, Object>{
        client.id: client,
      });
      final entries = await h.entries();
      expect((await h.byId(filed.entryId)).projectId, client.id);
      expect(
        entries.where((e) => e.projectId != null),
        hasLength(1),
        reason: 'the other entry of the same activity is still in none',
      );
    },
  );

  test('the restored timeline still satisfies SPEC §4', () async {
    await trackADay();
    final file = await exportAll();
    await h.writer.deleteAllData();
    await importInto(file);

    final entries = await h.entries();
    checkNoOverlap(entries);
    checkSingleRunning(entries);
    for (final entry in entries) {
      expect(entry.endUtc!.isAfter(entry.startUtc), isTrue);
    }
  });

  test('a deletion survives the round trip', () async {
    await trackADay();
    final liveBefore = (await h.entries()).length;
    final file = await exportAll();
    await h.writer.deleteAllData();
    await importInto(file);

    expect(
      (await h.entries()).length,
      liveBefore,
      reason: 'the deleted entry stays deleted rather than coming back',
    );
  });

  test('importing the same file twice is idempotent', () async {
    await trackADay();
    final file = await exportAll();
    final before = fingerprint(await h.entries());

    await importInto(file);
    await importInto(file);

    expect(fingerprint(await h.entries()), before);
  });

  test('a running entry survives, still running', () async {
    await h.writer.startByName(name: 'Writing specs');
    h.clock.advance(const Duration(minutes: 20));
    final file = await exportAll();

    await h.writer.deleteAllData();
    await importInto(file);

    final entries = await h.entries();
    expect(entries.single.isRunning, isTrue);
    checkSingleRunning(entries);
  });

  test('a rejected plan changes nothing (SPEC §4.6)', () async {
    await trackADay();
    final before = fingerprint(await h.entries());

    // A file that overlaps what is already here.
    final existing = await h.repository.readForBackup();
    final clash = BackupEntry(
      id: 'clash',
      activityId: existing.activities.first.id,
      startUtc: DateTime.utc(2026, 3, 10, 9, 30),
      endUtc: DateTime.utc(2026, 3, 10, 10, 30),
      tzName: 'Europe/Berlin',
      createdAt: h.now,
      updatedAt: h.now,
    );
    final text = encodeBackup(
      activities: existing.activities,
      entries: <BackupEntry>[clash],
      settings: const AppSettings(),
      exportedAt: h.now,
    );
    final plan = planMerge(
      incoming: (parseBackup(text) as BackupReadOk).file,
      existingEntries: existing.entries,
      existingActivities: existing.activities,
      now: h.now,
    );

    expect(plan.isApplicable, isFalse);
    await expectLater(
      () => h.writer.applyBackup(plan),
      throwsA(isA<InvariantViolation>()),
      reason: 'the writer refuses it too, not just the UI',
    );
    expect(fingerprint(await h.entries()), before, reason: 'nothing changed');
  });

  group('active sessions (SPEC §9.9)', () {
    BackupSession stored(
      String id,
      DateTime start,
      DateTime? end, {
      DateTime? lastSeen,
    }) => BackupSession(
      session: ActiveSession(
        id: id,
        startUtc: start,
        endUtc: end,
        lastSeenUtc: lastSeen ?? end ?? start,
        tzName: 'Europe/Berlin',
      ),
      createdAt: start,
      updatedAt: end ?? start,
    );

    final a = DateTime.utc(2026, 3, 10, 9);
    final b = DateTime.utc(2026, 3, 10, 10);
    final c = DateTime.utc(2026, 3, 10, 11);

    String encoded(List<BackupSession> sessions) => encodeBackup(
      activities: const <BackupActivity>[],
      entries: const <BackupEntry>[],
      sessions: sessions,
      settings: const AppSettings(trackActiveTime: true),
      exportedAt: a,
    );

    test('sessions survive the file', () {
      final read = parseBackup(encoded([stored('s1', a, b)])) as BackupReadOk;

      expect(read.file.sessions.single.session, stored('s1', a, b).session);
    });

    test('a v1 file loads, with no sessions', () {
      const v1 =
          '{"formatVersion": 1, "activities": [], "entries": [], '
          '"settings": {}}';

      expect((parseBackup(v1) as BackupReadOk).file.sessions, isEmpty);
    });

    test('importNeverEnablesTracking', () {
      final text = encoded(const <BackupSession>[]);

      expect(text, isNot(contains('trackActive')));
      expect(
        (parseBackup(text) as BackupReadOk).file.settings.trackActiveTime,
        isFalse,
      );
    });

    test('an overlapping session is skipped, not fatal', () {
      final merged = mergeSessions(
        incoming: [stored('new', a, c)],
        existing: [stored('here', b, c)],
      );

      expect(merged.map((s) => s.id), ['here']);
    });

    test('a non-overlapping session is added', () {
      final merged = mergeSessions(
        incoming: [stored('new', a, b)],
        existing: [stored('here', b, c)],
      );

      expect(merged.map((s) => s.id).toSet(), {'here', 'new'});
    });

    test('an imported open session ends where it was last seen', () {
      final merged = mergeSessions(
        incoming: [stored('open', a, null, lastSeen: b)],
        existing: const [],
      );

      expect(merged.single.session.endUtc, b);
      expect(merged.single.session.endReason, SessionEndReason.lost);
    });

    test('an imported session that was never seen is dropped', () {
      expect(
        mergeSessions(incoming: [stored('open', a, null)], existing: const []),
        isEmpty,
      );
    });

    test('applying a plan keeps the session open here', () async {
      await h.db.customStatement(
        'INSERT INTO active_sessions (id, start_utc, last_seen_utc, tz_name, '
        "created_at, updated_at) VALUES ('live', 1, 1, 'UTC', 1, 1)",
      );
      final existing = await h.db.select(h.db.activeSessions).get();
      final plan = planMerge(
        incoming:
            (parseBackup(encoded([stored('s1', a, b)])) as BackupReadOk).file,
        existingEntries: const [],
        existingActivities: const [],
        existingSessions: existing.map((row) => row.toBackup()).toList(),
        now: h.now,
      );

      await h.writer.applyBackup(plan);

      expect(await h.db.select(h.db.activeSessions).get(), hasLength(1 + 0));
    });
  });
}
