import '../../domain/models/activity.dart';
import '../../domain/models/time_entry.dart';
import 'database.dart';

/// Row <-> domain conversions. Kept in one place so the UTC-millis storage
/// convention (SPEC §5.3) is applied identically everywhere.
extension ActivityRowMapper on ActivityRow {
  Activity toDomain() => Activity(
    id: id,
    name: name,
    colorSeed: colorSeed,
    archived: archived != 0,
  );
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

DateTime _utc(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

int toMillis(DateTime instant) => instant.toUtc().millisecondsSinceEpoch;
