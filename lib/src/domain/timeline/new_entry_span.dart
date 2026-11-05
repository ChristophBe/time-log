import 'day_window.dart';
import 'invariants.dart';

/// How long an entry added from an empty day starts out (SPEC §8.2).
const Duration kNewEntryLength = Duration(minutes: 30);

/// The span **Add entry** proposes on a day with nothing on it (SPEC §8.2), or
/// null when there is no honest one to propose.
///
/// Today, it is the half hour just gone, since that is the time most likely to
/// have been missed — clipped at midnight, because the day owns its entries
/// (§6.11). A past day has no "just gone", so it gets 09:00 local, an ordinary
/// start that is easier to move than to invent. A future day gets nothing:
/// §4.5 forbids recording time that has not happened. Nor does a span shorter
/// than the editing minimum (§7.2), which is just after midnight.
///
/// It is a starting point and nothing more: the entry is then on the calendar,
/// to be corrected like any other.
({DateTime startUtc, DateTime endUtc})? newEntrySpan({
  required DayWindow day,
  required DateTime nowUtc,
}) {
  if (!day.startUtc.isBefore(nowUtc)) return null;
  final ({DateTime startUtc, DateTime endUtc}) span;
  if (day.contains(nowUtc)) {
    final start = nowUtc.subtract(kNewEntryLength);
    span = (
      startUtc: start.isBefore(day.startUtc) ? day.startUtc : start,
      endUtc: nowUtc,
    );
  } else {
    final nine = DateTime(day.year, day.month, day.day, 9).toUtc();
    span = (startUtc: nine, endUtc: nine.add(kNewEntryLength));
  }
  if (span.endUtc.difference(span.startUtc) < kMinEntryLength) return null;
  return span;
}
