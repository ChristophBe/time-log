import '../models/time_entry.dart';
import '../timeline/clipping.dart';
import 'active_session.dart';

/// Shorter than this is not offered: it could not be edited afterwards
/// (SPEC §7.2).
const Duration _minimumSpan = Duration(minutes: 1);

/// The parts of [sessions] inside `[from, to)` that no entry covers, oldest
/// first (SPEC §9.9).
///
/// Only uncovered time, so that logging one of these can never collide with an
/// entry. A running entry reaches [now], and so does an open session.
List<ClippedSpan> unloggedActive({
  required Iterable<ActiveSession> sessions,
  required Iterable<TimeEntry> entries,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final covered = <ClippedSpan>[
    for (final entry in entries)
      ?clipToWindow(entry, from: from, to: to, now: now),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final unlogged = <ClippedSpan>[];
  void add(DateTime start, DateTime end) {
    if (end.difference(start) >= _minimumSpan) {
      unlogged.add((start: start, end: end));
    }
  }

  for (final session in sessions) {
    final span = clipSpan(
      start: session.startUtc,
      end: session.endOr(now),
      from: from,
      to: to,
    );
    if (span == null) continue;
    var cursor = span.start;
    for (final entry in covered) {
      if (!entry.end.isAfter(cursor)) continue;
      if (!entry.start.isBefore(span.end)) break;
      if (entry.start.isAfter(cursor)) add(cursor, entry.start);
      cursor = entry.end;
    }
    if (cursor.isBefore(span.end)) add(cursor, span.end);
  }
  unlogged.sort((a, b) => a.start.compareTo(b.start));
  return unlogged;
}
