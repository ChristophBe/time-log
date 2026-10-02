import '../models/time_entry.dart';

/// Whether [entry] may be *continued* (reopened) rather than resumed as a new
/// entry -- SPEC §6.4.
///
/// Reopening is only legal while the entry is still the most recent one, it
/// ended within [window], and nothing else is running. Without this, picking
/// work back up a minute later fragments the timeline into touching clones of
/// the same activity.
bool canContinueEntry({
  required TimeEntry entry,
  required TimeEntry? lastFinished,
  required TimeEntry? running,
  required DateTime now,
  required Duration window,
}) {
  if (window <= Duration.zero) return false;
  if (running != null) return false;
  final end = entry.endUtc;
  if (end == null) return false;
  if (lastFinished == null || lastFinished.id != entry.id) return false;
  final gap = now.difference(end);
  if (gap.isNegative) return false;
  return gap <= window;
}
