import '../models/time_entry.dart';
import 'invariants.dart';

/// Which end of an entry a boundary belongs to.
enum BoundaryEdge { start, end }

/// Rounds an *instant* to the nearest [snap] (SPEC §7.3).
///
/// Snapping the instant rather than the drag delta is what stops an entry from
/// drifting off-grid after repeated edits: snapping deltas accumulates the
/// original offset forever.
DateTime snapInstant(DateTime instant, Duration snap) {
  if (snap <= Duration.zero) return instant;
  final snapMs = snap.inMilliseconds;
  final ms = instant.millisecondsSinceEpoch;
  final remainder = ms.remainder(snapMs);
  final down = ms - remainder;
  final up = down + snapMs;
  final rounded = (ms - down) < (up - ms) ? down : up;
  return DateTime.fromMillisecondsSinceEpoch(rounded, isUtc: instant.isUtc);
}

/// The outcome of moving one boundary: the new times for the dragged entry and,
/// when the boundary was shared with a neighbour, for that neighbour too.
///
/// Returning both in one value is what keeps "a shared boundary moves both
/// edges" (SPEC §7.1) a single tested decision instead of a rule scattered
/// across the UI.
class BoundaryMove {
  const BoundaryMove({
    required this.target,
    this.neighbour,
    required this.requested,
    required this.applied,
  });

  /// The dragged entry with its new times.
  final TimeEntry target;

  /// The adjacent entry with its new times, when the boundary was shared.
  final TimeEntry? neighbour;

  /// Where the boundary was asked to go (after snapping).
  final DateTime requested;

  /// Where it actually ended up after clamping.
  final DateTime applied;

  /// True when clamping stopped the boundary short of the request, which the UI
  /// answers with a haptic rather than an error (SPEC §7.2).
  bool get wasClamped => requested != applied;

  List<TimeEntry> get changedEntries => <TimeEntry>[target, ?neighbour];
}

/// Moves one boundary of [target], applying the whole of SPEC §7.
///
/// - A boundary *shared* with [prev]/[next] (the entries touch) moves both
///   edges, so total tracked time is conserved and no gap appears (§7.1).
/// - A *free* boundary moves alone, growing into or shrinking away from a gap.
/// - The result is clamped so it can never cross a far edge or breach the
///   minimum length, and never lands in the future (§7.2).
/// - The end of a running entry is not movable (§7.4).
BoundaryMove resolveBoundaryMove({
  required TimeEntry target,
  required BoundaryEdge edge,
  required DateTime desired,
  TimeEntry? prev,
  TimeEntry? next,
  required Duration snap,
  required DateTime now,
  Duration minLength = kMinEntryLength,
}) {
  if (edge == BoundaryEdge.end && target.isRunning) {
    throw const InvariantViolation(
      'runningEndNotEditable',
      'the running entry always ends now (SPEC §7.4)',
    );
  }

  final requested = snapInstant(desired.toUtc(), snap);

  if (edge == BoundaryEdge.start) {
    final targetEnd = target.endUtc;
    // Latest the start may go: keep minLength, and never past now.
    var latest = targetEnd == null ? now : targetEnd.subtract(minLength);
    if (latest.isAfter(now)) latest = now;

    final shared = prev != null && prev.endUtc == target.startUtc;
    // Earliest: a shared neighbour must keep its own minimum; a free edge may
    // grow back to the neighbour's end, or without one, to the start of time.
    final earliest = shared
        ? prev.startUtc.add(minLength)
        : (prev?.endUtc ?? DateTime.utc(1970));

    final applied = _clamp(requested, earliest, latest);
    return BoundaryMove(
      target: target.copyWith(startUtc: applied),
      neighbour: shared ? prev.copyWith(endUtc: applied) : null,
      requested: requested,
      applied: applied,
    );
  }

  // edge == end, target is finished.
  final earliest = target.startUtc.add(minLength);
  final shared = next != null && next.startUtc == target.endUtc;
  var latest = shared
      ? (next.endUtc?.subtract(minLength) ?? now)
      : (next?.startUtc ?? now);
  if (latest.isAfter(now)) latest = now;

  final applied = _clamp(requested, earliest, latest);
  return BoundaryMove(
    target: target.copyWith(endUtc: applied),
    neighbour: shared ? next.copyWith(startUtc: applied) : null,
    requested: requested,
    applied: applied,
  );
}

DateTime _clamp(DateTime value, DateTime min, DateTime max) {
  // A degenerate window (min after max) means there is no legal room at all;
  // hold the boundary at min so the entry keeps its minimum length.
  if (max.isBefore(min)) return min;
  if (value.isBefore(min)) return min;
  if (value.isAfter(max)) return max;
  return value;
}
