import '../models/time_entry.dart';

/// The shortest entry *boundary editing* will produce (SPEC §4.3, §7.2).
///
/// Deliberately not enforced on stop: a genuinely 20-second span is real data,
/// and pretending it lasted a minute would be a lie. The minimum exists so that
/// dragging cannot create degenerate, unhittable blocks.
const Duration kMinEntryLength = Duration(minutes: 1);

/// Thrown when an operation would leave the timeline invalid. The writer lets
/// this escape its transaction, which rolls the whole operation back, so the
/// timeline is never half-changed (SPEC §4.6).
class InvariantViolation implements Exception {
  const InvariantViolation(this.rule, this.detail);

  /// The SPEC §4 rule that would break, e.g. 'noOverlap'.
  final String rule;
  final String detail;

  @override
  String toString() => 'InvariantViolation($rule): $detail';
}

/// SPEC §4.3 and §4.5 for a single entry.
void checkEntry(TimeEntry entry, {required DateTime now}) {
  final end = entry.endUtc;
  if (end == null) {
    if (entry.startUtc.isAfter(now)) {
      throw InvariantViolation(
        'noFutureStarts',
        'running entry starts at ${entry.startUtc}, after now ($now)',
      );
    }
    return;
  }
  if (!end.isAfter(entry.startUtc)) {
    throw InvariantViolation(
      'positiveDuration',
      'entry ${entry.id} ends at $end, not after its start ${entry.startUtc}',
    );
  }
  if (end.isAfter(now)) {
    throw InvariantViolation(
      'noFutureStarts',
      'entry ${entry.id} ends in the future at $end',
    );
  }
}

/// SPEC §4.2: no two entries may cover the same instant. [entries] need not be
/// sorted; a running entry is treated as reaching forever.
void checkNoOverlap(Iterable<TimeEntry> entries) {
  final sorted = entries.toList()
    ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  for (var i = 0; i < sorted.length - 1; i++) {
    final current = sorted[i];
    final next = sorted[i + 1];
    final currentEnd = current.endUtc;
    if (currentEnd == null || currentEnd.isAfter(next.startUtc)) {
      throw InvariantViolation(
        'noOverlap',
        'entry ${current.id} (ends ${currentEnd ?? 'running'}) overlaps '
            '${next.id} (starts ${next.startUtc})',
      );
    }
  }
}

/// SPEC §4.1.
void checkSingleRunning(Iterable<TimeEntry> entries) {
  final running = entries.where((e) => e.isRunning).toList();
  if (running.length > 1) {
    throw InvariantViolation(
      'singleRunning',
      '${running.length} entries are running: '
          '${running.map((e) => e.id).join(', ')}',
    );
  }
}

/// Everything in SPEC §4 for a neighbourhood of entries.
void checkNeighbourhood(Iterable<TimeEntry> entries, {required DateTime now}) {
  for (final entry in entries) {
    checkEntry(entry, now: now);
  }
  checkSingleRunning(entries);
  checkNoOverlap(entries);
}
