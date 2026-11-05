import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';

/// Whether the process renders in Europe/Berlin: +01:00 in March, +02:00 after
/// the last Sunday of it.
final bool _isBerlin =
    DateTime(2026, 3, 10).timeZoneOffset == const Duration(hours: 1) &&
    DateTime(2026, 7, 1).timeZoneOffset == const Duration(hours: 2);

/// SPEC §5.3. The DST cases use [FixedDayWindowCalculator] so they do not depend
/// on the time zone of whatever machine runs the tests.
void main() {
  DayWindow window(DateTime start, DateTime end, int day) =>
      DayWindow(startUtc: start, endUtc: end, year: 2026, month: 3, day: day);

  test('a normal day is 24 hours', () {
    final w = window(DateTime.utc(2026, 3, 10), DateTime.utc(2026, 3, 11), 10);
    expect(w.length, const Duration(hours: 24));
  });

  test('dstShortDayHas23HourAxis', () {
    // Europe/Berlin, 29 March 2026: 02:00 local jumps to 03:00.
    final w = window(
      DateTime.utc(2026, 3, 28, 23),
      DateTime.utc(2026, 3, 29, 22),
      29,
    );
    expect(w.length, const Duration(hours: 23));
  });

  test('dstLongDayHas25HourAxis', () {
    final w = DayWindow(
      startUtc: DateTime.utc(2026, 10, 24, 22),
      endUtc: DateTime.utc(2026, 10, 25, 23),
      year: 2026,
      month: 10,
      day: 25,
    );
    expect(w.length, const Duration(hours: 25));
  });

  test('contains is half-open', () {
    final w = window(DateTime.utc(2026, 3, 10), DateTime.utc(2026, 3, 11), 10);
    expect(w.contains(DateTime.utc(2026, 3, 10)), isTrue);
    expect(w.contains(DateTime.utc(2026, 3, 10, 23, 59, 59)), isTrue);
    expect(
      w.contains(DateTime.utc(2026, 3, 11)),
      isFalse,
      reason: 'midnight belongs to the next day, so totals cannot double-count',
    );
  });

  test('offsetOf clamps to the window', () {
    final w = window(DateTime.utc(2026, 3, 10), DateTime.utc(2026, 3, 11), 10);
    expect(w.offsetOf(DateTime.utc(2026, 3, 10, 6)), const Duration(hours: 6));
    expect(w.offsetOf(DateTime.utc(2026, 3, 9)), Duration.zero);
    expect(w.offsetOf(DateTime.utc(2026, 3, 12)), const Duration(hours: 24));
  });

  test('isoDate is zero-padded', () {
    expect(
      window(DateTime.utc(2026, 3, 5), DateTime.utc(2026, 3, 6), 5).isoDate,
      '2026-03-05',
    );
  });

  group('LocalDayWindowCalculator', () {
    const calculator = LocalDayWindowCalculator();

    test('a day starts at local midnight', () {
      final w = calculator.forDate(2026, 3, 10);
      expect(w.startUtc.toLocal().hour, 0);
      expect(w.startUtc.toLocal().day, 10);
      expect(w.endUtc.toLocal().day, 11);
    });

    test('containing finds the day an instant falls in', () {
      final w = calculator.forDate(2026, 3, 10);
      final middle = w.startUtc.add(const Duration(hours: 12));
      expect(calculator.containing(middle), w);
    });

    test('next and previous step one day', () {
      final w = calculator.forDate(2026, 3, 10);
      expect(calculator.next(w).day, 11);
      expect(calculator.previous(w).day, 9);
    });

    // SPEC §5.3: a day is local midnight to local midnight in the *rendering*
    // zone, which is the device's, which Dart takes from the process (§12).
    // So this is the one test here that is about the zone the suite runs in:
    // under Europe/Berlin the day starts at 23:00 UTC the evening before, and
    // the spring-forward day is 23 hours long without anyone saying so.
    test('dayWindowFollowsRenderingZone', () {
      final march10 = calculator.forDate(2026, 3, 10);
      expect(march10.startUtc, DateTime(2026, 3, 10).toUtc());
      expect(march10.startUtc, DateTime.utc(2026, 3, 9, 23));

      final springForward = calculator.forDate(2026, 3, 29);
      expect(springForward.length, const Duration(hours: 23));
    }, skip: _isBerlin ? false : 'needs TZ=Europe/Berlin, as SPEC §12 says');

    test('stepping across a month boundary works', () {
      final w = calculator.forDate(2026, 3, 31);
      final next = calculator.next(w);
      expect(next.month, 4);
      expect(next.day, 1);
    });
  });
}
