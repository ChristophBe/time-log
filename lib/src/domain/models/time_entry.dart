import 'activity.dart';

/// One continuous span of doing an activity (SPEC §5.1).
///
/// [startUtc] and [endUtc] are always UTC; local time exists only for display
/// (SPEC §5.3). A null [endUtc] means this is the running entry, and there is at
/// most one of those (SPEC §4.1).
class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.activityId,
    required this.startUtc,
    required this.endUtc,
    required this.tzName,
    this.note,
  });

  final String id;
  final String activityId;
  final DateTime startUtc;
  final DateTime? endUtc;
  final String tzName;
  final String? note;

  /// Longest acceptable note (SPEC §5.1). Enforced by the writer rather than
  /// only by the text field, so no code path can store a longer one.
  static const int maxNoteLength = 2000;

  bool get isRunning => endUtc == null;

  /// The end of this entry, treating a running entry as ending "now".
  DateTime endOr(DateTime now) => endUtc ?? now;

  /// Duration, with a running entry measured up to [now]. Never negative: a
  /// backwards clock jump shows as zero rather than a negative readout
  /// (SPEC §9.2).
  Duration durationAt(DateTime now) {
    final span = endOr(now).difference(startUtc);
    return span.isNegative ? Duration.zero : span;
  }

  /// Whether this entry covers any part of the half-open window
  /// `[windowStart, windowEnd)`.
  bool overlapsWindow(DateTime windowStart, DateTime windowEnd, DateTime now) =>
      startUtc.isBefore(windowEnd) && endOr(now).isAfter(windowStart);

  TimeEntry copyWith({
    DateTime? startUtc,
    DateTime? endUtc,
    bool clearEnd = false,
    String? note,
    bool clearNote = false,
    String? activityId,
  }) => TimeEntry(
    id: id,
    activityId: activityId ?? this.activityId,
    startUtc: startUtc ?? this.startUtc,
    endUtc: clearEnd ? null : (endUtc ?? this.endUtc),
    tzName: tzName,
    note: clearNote ? null : (note ?? this.note),
  );

  @override
  bool operator ==(Object other) =>
      other is TimeEntry &&
      other.id == id &&
      other.activityId == activityId &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc &&
      other.note == note &&
      other.tzName == tzName;

  @override
  int get hashCode =>
      Object.hash(id, activityId, startUtc, endUtc, note, tzName);

  @override
  String toString() =>
      'TimeEntry($id, $activityId, $startUtc -> ${endUtc ?? 'running'})';
}

/// An entry paired with its activity, which is what the UI always needs.
class EntryWithActivity {
  const EntryWithActivity({required this.entry, required this.activity});

  final TimeEntry entry;
  final Activity activity;

  String get name => activity.name;
}
