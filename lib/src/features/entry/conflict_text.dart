import '../../core/formatters.dart';
import '../../domain/timeline/time_conflicts.dart';

/// Turns a [TimeConflict] into the inline message shown under the time fields
/// (SPEC §7.2). Names the neighbour and when it ends, so the user can see what
/// to change rather than only that something is wrong.
String describeConflict(
  TimeConflict conflict, {
  required bool use24h,
  String? previousName,
  String? nextName,
}) => switch (conflict) {
  OverlapsPrevious(:final untilUtc) =>
    'Overlaps ${previousName ?? 'the previous entry'} until '
        '${formatTimeOfDay(untilUtc.toLocal(), use24h: use24h)}',
  OverlapsNext(:final fromUtc) =>
    'Overlaps ${nextName ?? 'the next entry'} from '
        '${formatTimeOfDay(fromUtc.toLocal(), use24h: use24h)}',
  EndNotAfterStart() => 'The end must come after the start',
  ShorterThanMinimum(:final minimum) =>
    'An entry must be at least ${minimum.inMinutes} minute'
        '${minimum.inMinutes == 1 ? '' : 's'} long',
  InTheFuture() => 'That is in the future',
  PreviousWouldBeTooShort(:final minimum) =>
    'That would leave ${previousName ?? 'the previous entry'} under '
        '${minimum.inMinutes} minute${minimum.inMinutes == 1 ? '' : 's'}',
  NextWouldBeTooShort(:final minimum) =>
    'That would leave ${nextName ?? 'the next entry'} under '
        '${minimum.inMinutes} minute${minimum.inMinutes == 1 ? '' : 's'}',
};
