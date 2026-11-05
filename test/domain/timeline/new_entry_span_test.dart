import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';
import 'package:time_log/src/domain/timeline/new_entry_span.dart';

/// SPEC §8.2's **Add entry** on an empty day: what it proposes, and when it
/// proposes nothing.
void main() {
  // 10 March 2026, a UTC day, so the arithmetic below is the whole story.
  final day = DayWindow(
    startUtc: DateTime.utc(2026, 3, 10),
    endUtc: DateTime.utc(2026, 3, 11),
    year: 2026,
    month: 3,
    day: 10,
  );

  test('today, it is the half hour just gone', () {
    final now = DateTime.utc(2026, 3, 10, 14, 32);
    expect(newEntrySpan(day: day, nowUtc: now), (
      startUtc: DateTime.utc(2026, 3, 10, 14, 2),
      endUtc: now,
    ));
  });

  test('just after midnight it is clipped to the day', () {
    final now = DateTime.utc(2026, 3, 10, 0, 10);
    expect(newEntrySpan(day: day, nowUtc: now)?.startUtc, day.startUtc);
  });

  test('under the editing minimum it proposes nothing', () {
    final now = DateTime.utc(2026, 3, 10, 0, 0, 30);
    expect(newEntrySpan(day: day, nowUtc: now), isNull);
  });

  test('a past day starts at nine, local', () {
    final span = newEntrySpan(day: day, nowUtc: DateTime.utc(2026, 3, 12));
    expect(span!.startUtc, DateTime(2026, 3, 10, 9).toUtc());
    expect(span.endUtc.difference(span.startUtc), kNewEntryLength);
  });

  test('a future day proposes nothing (SPEC §4.5)', () {
    expect(
      newEntrySpan(day: day, nowUtc: DateTime.utc(2026, 3, 9, 12)),
      isNull,
    );
  });
}
