import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/backup/json_backup.dart';
import 'package:time_log/src/domain/models/app_settings.dart';

/// SPEC §8.6: the backup format and the merge rules.
void main() {
  final exportedAt = DateTime.utc(2026, 3, 11, 12);

  BackupEntry entry({
    required String id,
    required DateTime start,
    DateTime? end,
    bool running = false,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String activityId = 'a1',
    String? note,
  }) => BackupEntry(
    id: id,
    activityId: activityId,
    startUtc: start,
    endUtc: running ? null : (end ?? start.add(const Duration(hours: 1))),
    tzName: 'Europe/Berlin',
    note: note,
    createdAt: start,
    updatedAt: updatedAt ?? start,
    deletedAt: deletedAt,
  );

  BackupActivity activity({
    String id = 'a1',
    String name = 'Writing specs',
    DateTime? updatedAt,
  }) => BackupActivity(
    id: id,
    name: name,
    nameKey: name.toLowerCase(),
    colorSeed: 0,
    archived: false,
    createdAt: DateTime.utc(2026),
    updatedAt: updatedAt ?? DateTime.utc(2026),
  );

  String fileWith(List<BackupEntry> entries, [List<BackupActivity>? acts]) =>
      encodeBackup(
        activities: acts ?? <BackupActivity>[activity()],
        entries: entries,
        settings: const AppSettings(),
        exportedAt: exportedAt,
      );

  BackupFile parsed(String text) => (parseBackup(text) as BackupReadOk).file;

  group('the file', () {
    test('round-trips entries, activities and settings', () {
      final original = entry(
        id: 'e1',
        start: DateTime.utc(2026, 3, 10, 9),
        note: 'chapter 3',
      );
      final file = parsed(fileWith(<BackupEntry>[original]));

      expect(file.formatVersion, backupFormatVersion);
      expect(file.exportedAt, exportedAt);
      expect(file.entries.single.id, 'e1');
      expect(file.entries.single.note, 'chapter 3');
      expect(file.entries.single.startUtc, original.startUtc);
      expect(file.entries.single.endUtc, original.endUtc);
      expect(file.activities.single.name, 'Writing specs');
      expect(file.settings.snap, const AppSettings().snap);
    });

    test('keeps tombstones, so a deletion survives the trip', () {
      final file = parsed(
        fileWith(<BackupEntry>[
          entry(
            id: 'gone',
            start: DateTime.utc(2026, 3, 10, 9),
            deletedAt: DateTime.utc(2026, 3, 10, 10),
          ),
        ]),
      );
      expect(file.entries.single.isDeleted, isTrue);
    });

    test('a newer format is refused outright (SPEC §9.5)', () {
      final result = parseBackup('{"formatVersion": 99, "entries": []}');
      expect(result, isA<BackupReadFailed>());
      expect(
        (result as BackupReadFailed).reason,
        contains('newer version'),
        reason: 'never partially applied, and said in words',
      );
    });

    test('a file that is not JSON is refused by name', () {
      expect(parseBackup('not json at all'), isA<BackupReadFailed>());
    });

    test('a JSON file that is not a backup is refused', () {
      expect(parseBackup('{"hello": "world"}'), isA<BackupReadFailed>());
    });
  });

  group('merging (SPEC §8.6)', () {
    BackupPlan plan({
      required List<BackupEntry> incoming,
      required List<BackupEntry> existing,
      List<BackupActivity>? incomingActivities,
      List<BackupActivity>? existingActivities,
    }) => planMerge(
      incoming: parsed(fileWith(incoming, incomingActivities)),
      existingEntries: existing,
      existingActivities: existingActivities ?? <BackupActivity>[activity()],
      now: exportedAt,
    );

    test('an unknown id is added', () {
      final result = plan(
        incoming: <BackupEntry>[
          entry(id: 'new', start: DateTime.utc(2026, 3, 10, 9)),
        ],
        existing: <BackupEntry>[],
      );
      expect(result.added, 1);
      expect(result.updated, 0);
      expect(result.skipped, 0);
      expect(result.isApplicable, isTrue);
    });

    test('a newer updatedAt wins', () {
      final result = plan(
        incoming: <BackupEntry>[
          entry(
            id: 'e1',
            start: DateTime.utc(2026, 3, 10, 9),
            note: 'from the file',
            updatedAt: DateTime.utc(2026, 3, 11),
          ),
        ],
        existing: <BackupEntry>[
          entry(
            id: 'e1',
            start: DateTime.utc(2026, 3, 10, 9),
            note: 'already here',
            updatedAt: DateTime.utc(2026, 3, 10),
          ),
        ],
      );
      expect(result.updated, 1);
      expect(
        result.entriesToWrite.single.note,
        'from the file',
        reason: 'the newer fact wins',
      );
    });

    test('an older updatedAt is skipped', () {
      final result = plan(
        incoming: <BackupEntry>[
          entry(
            id: 'e1',
            start: DateTime.utc(2026, 3, 10, 9),
            note: 'stale',
            updatedAt: DateTime.utc(2026, 3, 9),
          ),
        ],
        existing: <BackupEntry>[
          entry(
            id: 'e1',
            start: DateTime.utc(2026, 3, 10, 9),
            note: 'current',
            updatedAt: DateTime.utc(2026, 3, 11),
          ),
        ],
      );
      expect(result.skipped, 1);
      expect(result.entriesToWrite.single.note, 'current');
    });

    test('an overlap with what is already here is rejected, by name', () {
      // The case that checking only the incoming file would let through: the
      // file is fine on its own, and wrong next to the database.
      final result = plan(
        incoming: <BackupEntry>[
          entry(id: 'incoming', start: DateTime.utc(2026, 3, 10, 9, 30)),
        ],
        existing: <BackupEntry>[
          entry(id: 'existing', start: DateTime.utc(2026, 3, 10, 9)),
        ],
      );
      expect(result.isApplicable, isFalse);
      expect(result.rejection, isNotNull);
      expect(result.rejection, contains('9'));
    });

    test('two running entries in the merged set are rejected', () {
      final result = plan(
        incoming: <BackupEntry>[
          entry(
            id: 'running-file',
            start: DateTime.utc(2026, 3, 11, 9),
            running: true,
          ),
        ],
        existing: <BackupEntry>[
          entry(
            id: 'running-db',
            start: DateTime.utc(2026, 3, 10, 9),
            running: true,
          ),
        ],
      );
      expect(result.isApplicable, isFalse);
    });

    test('an entry whose activity is nowhere is rejected', () {
      final result = plan(
        incoming: <BackupEntry>[
          entry(
            id: 'orphan',
            start: DateTime.utc(2026, 3, 10, 9),
            activityId: 'missing',
          ),
        ],
        existing: <BackupEntry>[],
      );
      expect(result.isApplicable, isFalse);
      expect(result.rejection, contains('missing'));
    });

    test('a deleted entry does not block the slot it used to hold', () {
      final result = plan(
        incoming: <BackupEntry>[
          entry(id: 'live', start: DateTime.utc(2026, 3, 10, 9)),
        ],
        existing: <BackupEntry>[
          entry(
            id: 'tombstone',
            start: DateTime.utc(2026, 3, 10, 9),
            deletedAt: DateTime.utc(2026, 3, 10, 12),
          ),
        ],
      );
      expect(
        result.isApplicable,
        isTrue,
        reason: 'a soft-deleted row occupies no time',
      );
    });

    test('importing the same file twice changes nothing the second time', () {
      final once = entry(id: 'e1', start: DateTime.utc(2026, 3, 10, 9));
      final result = plan(
        incoming: <BackupEntry>[once],
        existing: <BackupEntry>[once],
      );
      expect(result.added, 0);
      expect(result.updated, 0);
      expect(result.skipped, 1);
    });
  });
}
