import '../models/time_entry.dart';
import 'invariants.dart';

/// Why a typed start/end cannot be stored.
///
/// Typed input is reported rather than silently clamped (SPEC §7.2): if you type
/// a time, you meant it, and storing a different one without saying so would be
/// worse than refusing.
sealed class TimeConflict {
  const TimeConflict();
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

/// Trimming the neighbour would squeeze it below the minimum.
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
/// An overlap is not a conflict in itself: it trims the neighbour, shared or not
/// (SPEC §7.1), and the only limit is that the neighbour must keep a usable
/// length. [original] says which edges are actually being moved.
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

  final previousEnd = previous?.endUtc;
  if (previous != null &&
      previousEnd != null &&
      startUtc != original.startUtc &&
      startUtc.isBefore(previousEnd) &&
      startUtc.difference(previous.startUtc) < minLength) {
    return PreviousWouldBeTooShort(minLength);
  }

  final nextEnd = next?.endUtc;
  if (next != null &&
      nextEnd != null &&
      endUtc != null &&
      endUtc != original.endUtc &&
      endUtc.isAfter(next.startUtc) &&
      nextEnd.difference(endUtc) < minLength) {
    return NextWouldBeTooShort(minLength);
  }

  return null;
}

/// What a typed start/end pair does to the entries on either side, the typed
/// counterpart of `BoundaryMove`.
class TimesEdit {
  const TimesEdit({
    this.previous,
    this.next,
    this.detachedPrevious,
    this.detachedNext,
  });

  /// The neighbours with their new times, when the edit overlapped them or was
  /// asked to carry them.
  final TimeEntry? previous;
  final TimeEntry? next;

  /// The neighbours, unchanged, that this edit would open a gap beside. Whoever
  /// is committing the edit has to ask about these (SPEC §7.1).
  final TimeEntry? detachedPrevious;
  final TimeEntry? detachedNext;
}

/// Applies SPEC §7.1 to a typed start/end pair, without writing anything.
///
/// An edge that overlaps its neighbour trims it. One that moves away from a
/// neighbour it touched leaves it alone and reports it as detached, unless
/// [carryPrevious] or [carryNext] says the user chose to bring it along.
TimesEdit resolveTimesEdit({
  required TimeEntry original,
  required DateTime startUtc,
  DateTime? endUtc,
  TimeEntry? previous,
  TimeEntry? next,
  bool carryPrevious = false,
  bool carryNext = false,
}) {
  final previousEnd = previous?.endUtc;
  final overlapsPrevious =
      previousEnd != null && startUtc.isBefore(previousEnd);
  final leavesPrevious =
      previousEnd == original.startUtc && startUtc.isAfter(original.startUtc);

  final originalEnd = original.endUtc;
  final overlapsNext =
      next != null && endUtc != null && endUtc.isAfter(next.startUtc);
  final leavesNext =
      next != null &&
      endUtc != null &&
      originalEnd != null &&
      next.startUtc == originalEnd &&
      endUtc.isBefore(originalEnd);

  return TimesEdit(
    previous: overlapsPrevious || (leavesPrevious && carryPrevious)
        ? previous?.copyWith(endUtc: startUtc)
        : null,
    next: overlapsNext || (leavesNext && carryNext)
        ? next.copyWith(startUtc: endUtc)
        : null,
    detachedPrevious: leavesPrevious && !carryPrevious ? previous : null,
    detachedNext: leavesNext && !carryNext ? next : null,
  );
}
