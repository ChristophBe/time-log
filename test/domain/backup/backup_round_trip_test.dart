import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/backup/json_backup.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
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
}
