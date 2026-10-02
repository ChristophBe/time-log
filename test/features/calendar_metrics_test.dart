import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';
import 'package:time_log/src/features/calendar/calendar_metrics.dart';

/// SPEC §8.2 geometry. Pure arithmetic, no widget tree.
void main() {
  DayWindow dayOf(Duration length, {int day = 10}) => DayWindow(
    startUtc: DateTime.utc(2026, 3, day),
    endUtc: DateTime.utc(2026, 3, day).add(length),
    year: 2026,
    month: 3,
    day: day,
  );

  final normalDay = dayOf(const Duration(hours: 24));

  test('a normal day is 24 hours tall at the default zoom', () {
    final metrics = CalendarMetrics(window: normalDay, pixelsPerHour: 72);
    expect(metrics.totalHeight, 24 * 72);
  });

  test('dstShortDayIsShorterOnScreen', () {
    final short = CalendarMetrics(
      window: dayOf(const Duration(hours: 23)),
      pixelsPerHour: 72,
    );
    final long = CalendarMetrics(
      window: dayOf(const Duration(hours: 25)),
      pixelsPerHour: 72,
    );
    expect(short.totalHeight, 23 * 72);
    expect(long.totalHeight, 25 * 72);
  });

  test('offsets are measured from the start of the day', () {
    final metrics = CalendarMetrics(window: normalDay, pixelsPerHour: 60);
    expect(metrics.offsetFor(normalDay.startUtc), 0);
    expect(
      metrics.offsetFor(normalDay.startUtc.add(const Duration(hours: 6))),
      360,
    );
    expect(metrics.offsetFor(normalDay.endUtc), 24 * 60);
  });

  test('offsets clamp rather than running off the top or bottom', () {
    final metrics = CalendarMetrics(window: normalDay, pixelsPerHour: 60);
    expect(metrics.offsetFor(DateTime.utc(2026, 3, 1)), 0);
    expect(metrics.offsetFor(DateTime.utc(2026, 4, 1)), 24 * 60);
  });

  test('a short entry still gets a visible, hittable height', () {
    final metrics = CalendarMetrics(window: normalDay, pixelsPerHour: 72);
    expect(metrics.heightFor(const Duration(minutes: 1)), closeTo(1.2, 0.01));
    expect(
      metrics.renderedHeightFor(const Duration(minutes: 1)),
      metrics.minBlockHeight,
    );
    expect(
      metrics.renderedHeightFor(const Duration(hours: 1)),
      72,
      reason: 'a normal block is not inflated',
    );
  });

  test('instantAt is the inverse of offsetFor', () {
    final metrics = CalendarMetrics(window: normalDay, pixelsPerHour: 72);
    final instant = normalDay.startUtc.add(
      const Duration(hours: 9, minutes: 35),
    );
    expect(metrics.instantAt(metrics.offsetFor(instant)), instant);
  });

  test('instantAt clamps to the day', () {
    final metrics = CalendarMetrics(window: normalDay, pixelsPerHour: 72);
    expect(metrics.instantAt(-500), normalDay.startUtc);
    expect(metrics.instantAt(99999), normalDay.endUtc);
  });

  group('hour ticks', () {
    test('a normal day has 24', () {
      final metrics = CalendarMetrics(window: normalDay, pixelsPerHour: 72);
      expect(metrics.hourTicks(), hasLength(24));
    });

    test('a 23-hour day has 23, so no tick lands in the missing hour', () {
      final metrics = CalendarMetrics(
        window: dayOf(const Duration(hours: 23)),
        pixelsPerHour: 72,
      );
      expect(metrics.hourTicks(), hasLength(23));
    });

    test('a 25-hour day has 25', () {
      final metrics = CalendarMetrics(
        window: dayOf(const Duration(hours: 25)),
        pixelsPerHour: 72,
      );
      expect(metrics.hourTicks(), hasLength(25));
    });
  });

  test('half-hour hairlines appear only when there is room', () {
    final tight = CalendarMetrics(window: normalDay, pixelsPerHour: 72);
    final roomy = CalendarMetrics(window: normalDay, pixelsPerHour: 140);
    expect(tight.showsHalfHours, isFalse);
    expect(roomy.showsHalfHours, isTrue);
  });

  test('zoom is clamped to the documented range', () {
    final metrics = CalendarMetrics(window: normalDay, pixelsPerHour: 72);
    expect(metrics.withZoom(10).pixelsPerHour, 40);
    expect(metrics.withZoom(1000).pixelsPerHour, 240);
    expect(metrics.withZoom(120).pixelsPerHour, 120);
  });
}
