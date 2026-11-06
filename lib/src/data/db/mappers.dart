import '../../domain/backup/json_backup.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/project.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/presence/active_session.dart';
import 'database.dart';

/// Row <-> domain conversions. Kept in one place so the UTC-millis storage
/// convention (SPEC §5.3) is applied identically everywhere.
extension ActivityRowMapper on ActivityRow {
  Activity toDomain() => Activity(
    id: id,
    name: name,
    colorSeed: colorSeed,
    archived: archived != 0,
    projectId: projectId,
  );
}

extension ProjectRowMapper on ProjectRow {
  Project toDomain() => Project(id: id, name: name);
}

extension TimeEntryRowMapper on TimeEntryRow {
  TimeEntry toDomain() => TimeEntry(
    id: id,
    activityId: activityId,
    startUtc: _utc(startUtc),
    endUtc: endUtc == null ? null : _utc(endUtc!),
    tzName: tzName,
    note: note,
  );
}

extension ActiveSessionRowMapper on ActiveSessionRow {
  ActiveSession toDomain() => ActiveSession(
    id: id,
    startUtc: _utc(startUtc),
    endUtc: endUtc == null ? null : _utc(endUtc!),
    lastSeenUtc: _utc(lastSeenUtc),
    tzName: tzName,
    endReason: SessionEndReason.fromName(endReason),
  );
}

DateTime _utc(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

int toMillis(DateTime instant) => instant.toUtc().millisecondsSinceEpoch;

/// Rows <-> the backup format (SPEC §8.6).
///
/// Separate from the domain mappers above because a backup carries the
/// bookkeeping columns the app never draws — `createdAt`, `updatedAt` and the
/// tombstone — and those are what make a merge and a round trip possible.
extension ActivityBackupMapper on ActivityRow {
  BackupActivity toBackup() => BackupActivity(
    id: id,
    name: name,
    nameKey: nameKey,
    colorSeed: colorSeed,
    archived: archived != 0,
    projectId: projectId,
    createdAt: _utc(createdAt),
    updatedAt: _utc(updatedAt),
  );
}

extension ProjectBackupMapper on ProjectRow {
  BackupProject toBackup() => BackupProject(
    id: id,
    name: name,
    nameKey: nameKey,
    createdAt: _utc(createdAt),
    updatedAt: _utc(updatedAt),
  );
}

extension ActiveSessionBackupMapper on ActiveSessionRow {
  BackupSession toBackup() => BackupSession(
    session: toDomain(),
    createdAt: _utc(createdAt),
    updatedAt: _utc(updatedAt),
  );
}

extension TimeEntryBackupMapper on TimeEntryRow {
  BackupEntry toBackup() => BackupEntry(
    id: id,
    activityId: activityId,
    note: note,
    startUtc: _utc(startUtc),
    endUtc: endUtc == null ? null : _utc(endUtc!),
    tzName: tzName,
    createdAt: _utc(createdAt),
    updatedAt: _utc(updatedAt),
    deletedAt: deletedAt == null ? null : _utc(deletedAt!),
  );
}
