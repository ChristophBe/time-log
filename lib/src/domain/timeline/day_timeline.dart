import '../models/time_entry.dart';
import 'day_window.dart';

/// Gaps shorter than this are not drawn: a one-minute hole between two entries
/// is noise, not untracked time worth pointing at (SPEC §8.2).
const Duration kMinVisibleGap = Duration(minutes: 5);

/// One entry's slice of a day.
///
/// An entry crossing midnight is a single row in the database and appears as a
/// segment in each day it touches, with [continuesBefore] / [continuesAfter]
/// telling the UI to draw a continuation marker (SPEC §5.3).
class EntrySegment {
  const EntrySegment({
    required this.entry,
    required this.startUtc,
    required this.endUtc,
    required this.continuesBefore,
    required this.continuesAfter,
    required this.isRunning,
  });

  final TimeEntry entry;

  /// The visible part of the entry, clipped to the day.
  final DateTime startUtc;
  final DateTime endUtc;

  final bool continuesBefore;
  final bool continuesAfter;
  final bool isRunning;

  Duration get visibleDuration => endUtc.difference(startUtc);

  /// The entry's full length, which is what the label should state even when
  /// only part of it is on screen.
  Duration fullDuration(DateTime now) => entry.durationAt(now);
}

/// Untracked time inside the day (SPEC §4.7): shown, never silently absorbed.
class GapSlot {
  const GapSlot({required this.startUtc, required this.endUtc});

  final DateTime startUtc;
  final DateTime endUtc;

  Duration get duration => endUtc.difference(startUtc);
}

class DayTimeline {
  const DayTimeline({
    required this.window,
    required this.segments,
    required this.gaps,
  });

  final DayWindow window;
  final List<EntrySegment> segments;
  final List<GapSlot> gaps;

  bool get isEmpty => segments.isEmpty;
}

/// Turns the entries touching a day into drawable segments and gaps.
///
/// Input entries are assumed non-overlapping (SPEC §4.2) and are sorted here
/// defensively. Nothing is stretched to close a gap.
DayTimeline buildDayTimeline({
  required DayWindow window,
  required Iterable<TimeEntry> entries,
  required DateTime now,
  Duration minVisibleGap = kMinVisibleGap,
}) {
  final sorted = entries.toList()
    ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

  final segments = <EntrySegment>[];
  for (final entry in sorted) {
    final entryEnd = entry.endOr(now);
    // Skip anything that does not actually intersect the day.
    if (!entry.startUtc.isBefore(window.endUtc)) continue;
    if (!entryEnd.isAfter(window.startUtc)) continue;

    final start = entry.startUtc.isBefore(window.startUtc)
        ? window.startUtc
        : entry.startUtc;
    final end = entryEnd.isAfter(window.endUtc) ? window.endUtc : entryEnd;
    if (!end.isAfter(start)) continue;

    segments.add(
      EntrySegment(
        entry: entry,
        startUtc: start,
        endUtc: end,
        continuesBefore: entry.startUtc.isBefore(window.startUtc),
        continuesAfter: entryEnd.isAfter(window.endUtc),
        isRunning: entry.isRunning,
      ),
    );
  }

  // Gaps are only meaningful up to now: the rest of today is not "untracked",
  // it simply has not happened yet.
  final horizon = now.isBefore(window.endUtc) ? now : window.endUtc;
  final gaps = <GapSlot>[];
  var cursor = window.startUtc;
  for (final segment in segments) {
    if (segment.startUtc.isAfter(cursor)) {
      final end = segment.startUtc.isAfter(horizon)
          ? horizon
          : segment.startUtc;
      if (end.difference(cursor) >= minVisibleGap) {
        gaps.add(GapSlot(startUtc: cursor, endUtc: end));
      }
    }
    if (segment.endUtc.isAfter(cursor)) cursor = segment.endUtc;
  }
  if (horizon.difference(cursor) >= minVisibleGap) {
    gaps.add(GapSlot(startUtc: cursor, endUtc: horizon));
  }

  return DayTimeline(window: window, segments: segments, gaps: gaps);
}
