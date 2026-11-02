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
/// when the move changes a neighbour, for that neighbour too.
///
/// Returning both in one value is what keeps "when does a neighbour change"
/// (SPEC §7.1) a single tested decision instead of a rule scattered across the
/// UI.
class BoundaryMove {
  const BoundaryMove({
    required this.target,
    this.neighbour,
    this.detachedNeighbour,
    required this.requested,
    required this.applied,
  });

  /// The dragged entry with its new times.
  final TimeEntry target;

  /// The adjacent entry with its new times, when the move overlapped it or was
  /// asked to carry it.
  final TimeEntry? neighbour;

  /// The adjacent entry, unchanged, when this move would open a gap beside it.
  /// Whoever is committing the move has to ask about this one (SPEC §7.1).
  final TimeEntry? detachedNeighbour;

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
/// - A move into [prev]/[next] trims that neighbour, shared or not (§7.1).
/// - A move *away* from a neighbour it touched leaves that neighbour alone and
///   reports it as [BoundaryMove.detachedNeighbour], unless [carryNeighbour]
///   says the user chose to bring it along (§7.1).
/// - A *free* boundary inside its gap moves alone.
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
  bool carryNeighbour = false,
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

    final prevEnd = prev?.endUtc;
    // Earliest: a neighbour may be trimmed but must keep its own minimum. One
    // already under it stays as recorded (SPEC §4.3), so the limit is its end.
    var earliest = DateTime.utc(1970);
    if (prev != null && prevEnd != null) {
      final keepsMinimum = prev.startUtc.add(minLength);
      earliest = keepsMinimum.isAfter(prevEnd) ? prevEnd : keepsMinimum;
    }

    final applied = _clamp(requested, earliest, latest);
    final overlaps = prevEnd != null && applied.isBefore(prevEnd);
    final movedAway =
        prevEnd == target.startUtc && applied.isAfter(target.startUtc);
    return BoundaryMove(
      target: target.copyWith(startUtc: applied),
      neighbour: overlaps || (movedAway && carryNeighbour)
          ? prev?.copyWith(endUtc: applied)
          : null,
      detachedNeighbour: movedAway && !carryNeighbour ? prev : null,
      requested: requested,
      applied: applied,
    );
  }

  // edge == end, target is finished.
  final earliest = target.startUtc.add(minLength);
  final nextEnd = next?.endUtc;
  // The mirror image of the start's limit. A running neighbour has no far edge,
  // so it can be trimmed right up to now.
  var latest = now;
  if (next != null && nextEnd != null) {
    final keepsMinimum = nextEnd.subtract(minLength);
    latest = keepsMinimum.isBefore(next.startUtc)
        ? next.startUtc
        : keepsMinimum;
  }
  if (latest.isAfter(now)) latest = now;

  final applied = _clamp(requested, earliest, latest);
  final overlaps = next != null && applied.isAfter(next.startUtc);
  final movedAway =
      next?.startUtc == target.endUtc && applied.isBefore(target.endUtc!);
  return BoundaryMove(
    target: target.copyWith(endUtc: applied),
    neighbour: overlaps || (movedAway && carryNeighbour)
        ? next?.copyWith(startUtc: applied)
        : null,
    detachedNeighbour: movedAway && !carryNeighbour ? next : null,
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
