import 'dart:convert';

import '../models/app_settings.dart';
import '../models/time_entry.dart';
import '../timeline/invariants.dart';

/// The format version written into every backup and checked on read.
///
/// Bumped when the *file* changes shape, which is not the same as the database
/// schema version: SPEC §5.4 requires a file written today to stay importable
/// by later versions of the app.
const int backupFormatVersion = 1;

/// One stored entry, with the bookkeeping columns the domain model leaves out.
///
/// `TimeEntry` carries what the app draws; a backup has to carry what the
/// database holds — `createdAt`, `updatedAt` and the soft-delete tombstone —
/// because `updatedAt` is how a merge decides a winner (SPEC §8.6) and the
/// tombstone is how a deletion survives a round trip at all.
class BackupEntry {
  const BackupEntry({
    required this.id,
    required this.activityId,
    required this.startUtc,
    required this.endUtc,
    required this.tzName,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.deletedAt,
  });

  final String id;
  final String activityId;
  final String? note;
  final DateTime startUtc;
  final DateTime? endUtc;
  final String tzName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  TimeEntry toTimeEntry() => TimeEntry(
    id: id,
    activityId: activityId,
    startUtc: startUtc,
    endUtc: endUtc,
    tzName: tzName,
    note: note,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'activityId': activityId,
    'note': note,
    'startUtc': startUtc.toUtc().toIso8601String(),
    'endUtc': endUtc?.toUtc().toIso8601String(),
    'tzName': tzName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  static BackupEntry fromJson(Map<String, Object?> json) => BackupEntry(
    id: _string(json, 'id'),
    activityId: _string(json, 'activityId'),
    note: json['note'] as String?,
    startUtc: _instant(json, 'startUtc')!,
    endUtc: _instant(json, 'endUtc'),
    tzName: _string(json, 'tzName'),
    createdAt: _instant(json, 'createdAt') ?? _instant(json, 'startUtc')!,
    updatedAt: _instant(json, 'updatedAt') ?? _instant(json, 'startUtc')!,
    deletedAt: _instant(json, 'deletedAt'),
  );
}

/// One stored activity, likewise with its bookkeeping.
class BackupActivity {
  const BackupActivity({
    required this.id,
    required this.name,
    required this.nameKey,
    required this.colorSeed,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String nameKey;
  final int colorSeed;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'nameKey': nameKey,
    'colorSeed': colorSeed,
    'archived': archived,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static BackupActivity fromJson(Map<String, Object?> json) => BackupActivity(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    nameKey: json['nameKey'] as String? ?? _string(json, 'name'),
    colorSeed: (json['colorSeed'] as num?)?.toInt() ?? 0,
    archived: json['archived'] == true,
    createdAt: _instant(json, 'createdAt') ?? DateTime.utc(2000),
    updatedAt: _instant(json, 'updatedAt') ?? DateTime.utc(2000),
  );
}

/// A whole backup: everything the app holds (SPEC §8.6).
class BackupFile {
  const BackupFile({
    required this.formatVersion,
    required this.exportedAt,
    required this.activities,
    required this.entries,
    required this.settings,
  });

  final int formatVersion;
  final DateTime exportedAt;
  final List<BackupActivity> activities;
  final List<BackupEntry> entries;
  final AppSettings settings;
}

/// Everything, as a file (SPEC §8.6).
String encodeBackup({
  required Iterable<BackupActivity> activities,
  required Iterable<BackupEntry> entries,
  required AppSettings settings,
  required DateTime exportedAt,
}) => const JsonEncoder.withIndent('  ').convert(<String, Object?>{
  'formatVersion': backupFormatVersion,
  'exportedAt': exportedAt.toUtc().toIso8601String(),
  'settings': <String, Object?>{
    'snapMinutes': settings.snap.inMinutes,
    'use24HourClock': settings.use24HourClock,
    'themeMode': settings.themeMode.name,
    'pixelsPerHour': settings.pixelsPerHour,
    'continueMinutes': settings.continueWindow.inMinutes,
    'firstDayOfWeek': settings.firstDayOfWeek,
    'longRunMinutes': settings.longRun.inMinutes,
  },
  'activities': <Object?>[for (final a in activities) a.toJson()],
  'entries': <Object?>[for (final e in entries) e.toJson()],
});

/// The result of reading a file: either a backup, or a reason it is not one.
sealed class BackupRead {
  const BackupRead();
}

class BackupReadOk extends BackupRead {
  const BackupReadOk(this.file);
  final BackupFile file;
}

class BackupReadFailed extends BackupRead {
  const BackupReadFailed(this.reason);
  final String reason;
}

/// Reads [text] as a backup, naming the problem rather than throwing.
///
/// A file from a *newer* format is refused outright and never partially
/// applied (SPEC §9.5): this version cannot know what it would be dropping.
BackupRead parseBackup(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (error) {
    return BackupReadFailed('That file is not JSON (${error.message}).');
  }
  if (decoded is! Map<String, Object?>) {
    return const BackupReadFailed('That file is not a time-log backup.');
  }

  final version = (decoded['formatVersion'] as num?)?.toInt();
  if (version == null) {
    return const BackupReadFailed('That file is not a time-log backup.');
  }
  if (version > backupFormatVersion) {
    return BackupReadFailed(
      'That backup was written by a newer version of time-log '
      '(format $version; this one reads $backupFormatVersion).',
    );
  }

  try {
    final settings = decoded['settings'] as Map<String, Object?>? ?? const {};
    return BackupReadOk(
      BackupFile(
        formatVersion: version,
        exportedAt: _instant(decoded, 'exportedAt') ?? DateTime.utc(2000),
        activities: <BackupActivity>[
          for (final a in (decoded['activities'] as List<Object?>? ?? const []))
            BackupActivity.fromJson(a! as Map<String, Object?>),
        ],
        entries: <BackupEntry>[
          for (final e in (decoded['entries'] as List<Object?>? ?? const []))
            BackupEntry.fromJson(e! as Map<String, Object?>),
        ],
        settings: AppSettings(
          snap: Duration(
            minutes: (settings['snapMinutes'] as num?)?.toInt() ?? 5,
          ),
          use24HourClock: settings['use24HourClock'] as bool? ?? true,
          themeMode: AppThemeMode.values.firstWhere(
            (mode) => mode.name == settings['themeMode'],
            orElse: () => AppThemeMode.system,
          ),
          pixelsPerHour:
              (settings['pixelsPerHour'] as num?)?.toDouble() ?? 72.0,
          continueWindow: Duration(
            minutes: (settings['continueMinutes'] as num?)?.toInt() ?? 5,
          ),
          firstDayOfWeek: (settings['firstDayOfWeek'] as num?)?.toInt() ?? 0,
          longRun: Duration(
            minutes: (settings['longRunMinutes'] as num?)?.toInt() ?? 480,
          ),
        ),
      ),
    );
  } on Object catch (error) {
    return BackupReadFailed('That backup could not be read ($error).');
  }
}

/// What importing a file would do, before it does it (SPEC §8.6).
class BackupPlan {
  const BackupPlan({
    required this.file,
    required this.entriesToWrite,
    required this.activitiesToWrite,
    required this.added,
    required this.updated,
    required this.skipped,
    this.rejection,
  });

  final BackupFile file;

  /// The rows to write if this plan is applied, already merged.
  final List<BackupEntry> entriesToWrite;
  final List<BackupActivity> activitiesToWrite;

  final int added;
  final int updated;
  final int skipped;

  /// Why this file cannot be applied, naming the first offending pair, or null
  /// if it can.
  final String? rejection;

  bool get isApplicable => rejection == null;
  int get rejected => rejection == null ? 0 : file.entries.length;
}

/// Works out what [incoming] would change, and whether it may.
///
/// Merge by `id`, newest `updatedAt` wins (SPEC §8.6). The §4 check runs over
/// the **merged** timeline rather than over the incoming entries alone — a file
/// that is internally consistent can still overlap what is already here, and
/// checking only the file is exactly how that gets through.
BackupPlan planMerge({
  required BackupFile incoming,
  required List<BackupEntry> existingEntries,
  required List<BackupActivity> existingActivities,
  required DateTime now,
}) {
  final merged = <String, BackupEntry>{
    for (final entry in existingEntries) entry.id: entry,
  };
  var added = 0;
  var updated = 0;
  var skipped = 0;

  for (final entry in incoming.entries) {
    final existing = merged[entry.id];
    if (existing == null) {
      merged[entry.id] = entry;
      added++;
    } else if (entry.updatedAt.isAfter(existing.updatedAt)) {
      merged[entry.id] = entry;
      updated++;
    } else {
      skipped++;
    }
  }

  final mergedActivities = <String, BackupActivity>{
    for (final activity in existingActivities) activity.id: activity,
  };
  for (final activity in incoming.activities) {
    final existing = mergedActivities[activity.id];
    if (existing == null || activity.updatedAt.isAfter(existing.updatedAt)) {
      mergedActivities[activity.id] = activity;
    }
  }

  final live = <TimeEntry>[
    for (final entry in merged.values)
      if (!entry.isDeleted) entry.toTimeEntry(),
  ]..sort((a, b) => a.startUtc.compareTo(b.startUtc));

  String? rejection;
  try {
    checkSingleRunning(live);
    checkNoOverlap(live);
    for (final entry in live) {
      if (entry.endUtc != null && !entry.endUtc!.isAfter(entry.startUtc)) {
        throw InvariantViolation(
          'An entry ends before it starts',
          'Entry ${entry.id} ends at or before its own start.',
        );
      }
    }
    // Every entry has to belong to an activity that will exist afterwards.
    for (final entry in live) {
      if (!mergedActivities.containsKey(entry.activityId)) {
        throw InvariantViolation(
          'Missing activity',
          'Entry ${entry.id} refers to activity ${entry.activityId}, which is '
              'not in the file or the database.',
        );
      }
    }
  } on InvariantViolation catch (violation) {
    rejection = violation.detail;
  }

  return BackupPlan(
    file: incoming,
    entriesToWrite: merged.values.toList(),
    activitiesToWrite: mergedActivities.values.toList(),
    added: added,
    updated: updated,
    skipped: skipped,
    rejection: rejection,
  );
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('"$key" is missing or not a string');
  }
  return value;
}

DateTime? _instant(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return DateTime.parse(value).toUtc();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  throw FormatException('"$key" is not a time');
}
