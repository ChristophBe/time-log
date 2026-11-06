import '../models/activity.dart';
import '../models/project.dart';
import '../models/time_entry.dart';
import '../timeline/clipping.dart';

/// A CSV extract and the two numbers worth showing before you commit to it.
class CsvExport {
  const CsvExport({
    required this.text,
    required this.rowCount,
    required this.total,
  });

  final String text;

  /// Rows, not counting the header.
  final int rowCount;

  /// The sum of every row's `duration_minutes`, to the minute.
  final Duration total;

  bool get isEmpty => rowCount == 0;
}

/// Which project's time an export covers (SPEC §8.6). Value-equal, because it
/// is part of a provider's argument.
sealed class ProjectFilter {
  const ProjectFilter();

  /// Whether an entry of [activity] belongs in the file. An entry whose
  /// activity cannot be found is in no project.
  bool matches(Activity? activity);
}

/// Everything, whatever project it is in.
class AllProjects extends ProjectFilter {
  const AllProjects();

  @override
  bool matches(Activity? activity) => true;

  @override
  bool operator ==(Object other) => other is AllProjects;

  @override
  int get hashCode => (AllProjects).hashCode;
}

/// Only activities in no project.
class NoProject extends ProjectFilter {
  const NoProject();

  @override
  bool matches(Activity? activity) => activity?.projectId == null;

  @override
  bool operator ==(Object other) => other is NoProject;

  @override
  int get hashCode => (NoProject).hashCode;
}

/// Only the activities of one project.
class OnlyProject extends ProjectFilter {
  const OnlyProject(this.projectId);

  final String projectId;

  @override
  bool matches(Activity? activity) => activity?.projectId == projectId;

  @override
  bool operator ==(Object other) =>
      other is OnlyProject && other.projectId == projectId;

  @override
  int get hashCode => projectId.hashCode;
}

/// The columns, in SPEC §8.6's order.
const List<String> csvColumns = <String>[
  'id',
  'activity',
  'project',
  'note',
  'start_local',
  'end_local',
  'start_utc',
  'end_utc',
  'duration_minutes',
  'tz',
];

/// The entries in `[fromUtc, toUtc)`, as a spreadsheet can read them.
///
/// This is an *extract*, not the backup of SPEC §8.6: a slice of the timeline
/// for a human or a spreadsheet, not something `import` round-trips. Three
/// decisions worth knowing before reading a file it produced:
///
/// **Rows describe the slice, not the entry.** An entry that began the evening
/// before [fromUtc] is reported starting at [fromUtc], because a row whose
/// `duration_minutes` disagreed with its own timestamps would be useless. The
/// `id` is still the entry's, so the same entry can appear in two adjacent
/// exports as two different slices — that is the honest cost of clipping, and
/// it is what makes `duration_minutes` sum to exactly the time tracked in the
/// range.
///
/// **A running entry is included and stays open.** Its end columns are empty
/// and its duration is measured to [now]. Leaving it out would take hours off
/// the total with nothing on the page to explain the gap; filling in an end
/// would record a moment that never happened.
///
/// **Times are written for machines.** The `*_utc` columns are ISO 8601 and the
/// `*_local` columns are `YYYY-MM-DD HH:MM`, whatever the 12/24-hour display
/// setting says: a file is not a screen.
///
/// [project] narrows the file to one project's activities (SPEC §8.6); the
/// count and total then describe only the rows that were kept.
CsvExport buildCsv({
  required Iterable<TimeEntry> entries,
  required Map<String, Activity> activities,
  required DateTime fromUtc,
  required DateTime toUtc,
  required DateTime now,
  Map<String, Project> projects = const <String, Project>{},
  ProjectFilter project = const AllProjects(),
}) {
  final rows = <String>[];
  var total = Duration.zero;

  final ordered = entries.toList()
    ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

  for (final entry in ordered) {
    final activity = activities[entry.activityId];
    if (!project.matches(activity)) continue;
    final span = clipToWindow(entry, from: fromUtc, to: toUtc, now: now);
    if (span == null) continue;

    final minutes = span.end.difference(span.start).inMinutes;
    total += Duration(minutes: minutes);

    // The end columns stay empty for an entry that has not finished, even
    // though the slice has an end: that end is "now", not the entry's.
    final open = entry.isRunning && span.end == entry.endOr(now);

    rows.add(
      _row(<String>[
        entry.id,
        activity?.name ?? '',
        projects[activity?.projectId]?.name ?? '',
        entry.note ?? '',
        _localStamp(span.start),
        open ? '' : _localStamp(span.end),
        span.start.toUtc().toIso8601String(),
        open ? '' : span.end.toUtc().toIso8601String(),
        '$minutes',
        entry.tzName,
      ]),
    );
  }

  // A BOM, because Excel on Windows reads a UTF-8 file without one as Latin-1
  // and turns every non-ASCII activity name into mojibake. CRLF for the same
  // reason -- RFC 4180 asks for it and spreadsheets expect it.
  final buffer = StringBuffer('﻿')
    ..write(_row(csvColumns))
    ..writeAll(rows);

  return CsvExport(
    text: buffer.toString(),
    rowCount: rows.length,
    total: total,
  );
}

/// `time-log-2026-03-01_2026-03-31.csv`, so the range is legible in a downloads
/// folder and two exports never collide.
///
/// A [project] other than the whole lot goes in front of the range —
/// `time-log-client-a-…` or `time-log-no-project-…` — so two exports of one
/// range for different projects do not collide either. [projectName] is the
/// project's name for [OnlyProject].
String csvFileName({
  required DateTime firstDay,
  required DateTime lastDay,
  ProjectFilter project = const AllProjects(),
  String? projectName,
}) {
  final label = switch (project) {
    AllProjects() => null,
    NoProject() => 'no-project',
    OnlyProject() => _slug(projectName ?? ''),
  };
  final prefix = label == null || label.isEmpty ? '' : '$label-';
  return 'time-log-$prefix${_dateStamp(firstDay)}_${_dateStamp(lastDay)}.csv';
}

/// Lowercase, and anything but a letter or a digit collapsed to one `-`.
/// Unicode letters are kept: a file name can hold "café", and dropping it would
/// leave "caf".
String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _row(List<String> fields) => '${fields.map(_escape).join(',')}\r\n';

/// RFC 4180. Notes are free text, so this is not theoretical: a note is exactly
/// where a comma, a quotation mark or a line break turns up.
String _escape(String field) {
  if (!field.contains(RegExp('[,"\r\n]'))) return field;
  return '"${field.replaceAll('"', '""')}"';
}

String _localStamp(DateTime utc) {
  final l = utc.toLocal();
  return '${_dateStamp(l)} ${_two(l.hour)}:${_two(l.minute)}';
}

String _dateStamp(DateTime local) =>
    '${local.year}-${_two(local.month)}-${_two(local.day)}';

String _two(int value) => value.toString().padLeft(2, '0');
