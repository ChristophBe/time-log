import '../models/time_entry.dart';
import 'invariants.dart';

/// Why a typed start/end cannot be stored.
///
/// Typed input is reported rather than silently clamped (SPEC §7.2): if you type
/// a time, you meant it, and moving it somewhere else without saying so would
/// be worse than refusing.
sealed class TimeConflict {
  const TimeConflict();
}

/// The new start would reach back into the previous entry, which ends at [until].
class OverlapsPrevious extends TimeConflict {
  const OverlapsPrevious(this.untilUtc);

  final DateTime untilUtc;
}

/// The new end would reach into the next entry, which starts at [from].
class OverlapsNext extends TimeConflict {
  const OverlapsNext(this.fromUtc);

  final DateTime fromUtc;
}

class EndNotAfterStart extends TimeConflict {
  const EndNotAfterStart();
}

class ShorterThanMinimum extends TimeConflict {
  const ShorterThanMinimum(this.minimum);

  final Duration minimum;
}

class InTheFuture extends TimeConflict {
  const InTheFuture();
}

/// Moving a shared boundary would squeeze the neighbour below the minimum.
class PreviousWouldBeTooShort extends TimeConflict {
  const PreviousWouldBeTooShort(this.minimum);

  final Duration minimum;
}

class NextWouldBeTooShort extends TimeConflict {
  const NextWouldBeTooShort(this.minimum);

  final Duration minimum;
}

/// Checks a typed start/end pair against SPEC §4, without writing anything.
///
/// Returns `null` when the times are storable. The UI calls this as the user
/// types so the conflict is visible before they commit.
///
/// [original] is needed to tell a *shared* boundary from a free one (SPEC §7.1):
/// if the edge being moved was touching its neighbour, moving it carries the
/// neighbour along, so it is not an overlap -- the only limit is that the
/// neighbour must keep a usable length.
TimeConflict? findTimeConflict({
  required TimeEntry original,
  required DateTime startUtc,
  DateTime? endUtc,
  TimeEntry? previous,
  TimeEntry? next,
  required DateTime now,
  Duration minLength = kMinEntryLength,
}) {
  if (startUtc.isAfter(now)) return const InTheFuture();

  if (endUtc != null) {
    if (!endUtc.isAfter(startUtc)) return const EndNotAfterStart();
    if (endUtc.isAfter(now)) return const InTheFuture();
    if (endUtc.difference(startUtc) < minLength) {
      return ShorterThanMinimum(minLength);
    }
  }

  final movesStart = startUtc != original.startUtc;
  final movesEnd = endUtc != original.endUtc;
  final sharesStart = previous?.endUtc == original.startUtc;
  final sharesEnd = next != null && next.startUtc == original.endUtc;

  if (movesStart && previous != null) {
    if (sharesStart) {
      // The neighbour's end comes with us; it just may not vanish.
      if (startUtc.difference(previous.startUtc) < minLength) {
        return PreviousWouldBeTooShort(minLength);
      }
    } else {
      final previousEnd = previous.endUtc;
      if (previousEnd != null && startUtc.isBefore(previousEnd)) {
        return OverlapsPrevious(previousEnd);
      }
      if (previous.isRunning && !startUtc.isBefore(previous.startUtc)) {
        return OverlapsPrevious(previous.startUtc);
      }
    }
  }

  if (next != null) {
    final effectiveEnd = endUtc ?? now;
    if (movesEnd && sharesEnd) {
      final nextEnd = next.endUtc;
      if (nextEnd != null && nextEnd.difference(effectiveEnd) < minLength) {
        return NextWouldBeTooShort(minLength);
      }
    } else if (effectiveEnd.isAfter(next.startUtc)) {
      return OverlapsNext(next.startUtc);
    }
  }

  return null;
}
