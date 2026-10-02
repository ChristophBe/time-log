/// The half-open instant range `[startUtc, endUtc)` covering one local calendar
/// day (SPEC §5.3).
///
/// Its [length] is 23 or 25 hours on the days a DST transition falls in, which
/// is why the calendar axis is built from this rather than from `hour * 60`.
class DayWindow {
  const DayWindow({
    required this.startUtc,
    required this.endUtc,
    required this.year,
    required this.month,
    required this.day,
  });

  final DateTime startUtc;
  final DateTime endUtc;
  final int year;
  final int month;
  final int day;

  Duration get length => endUtc.difference(startUtc);

  bool contains(DateTime instantUtc) =>
      !instantUtc.isBefore(startUtc) && instantUtc.isBefore(endUtc);

  /// How far [instantUtc] sits into the day, clamped to the window.
  Duration offsetOf(DateTime instantUtc) {
    if (instantUtc.isBefore(startUtc)) return Duration.zero;
    if (instantUtc.isAfter(endUtc)) return length;
    return instantUtc.difference(startUtc);
  }

  String get isoDate =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DayWindow &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(startUtc, endUtc, year, month, day);

  @override
  String toString() => 'DayWindow($isoDate, ${length.inHours}h)';
}

/// Turns calendar dates into [DayWindow]s.
///
/// Injected rather than called statically so a 23- or 25-hour day can be handed
/// to the calendar in a test without depending on the test host's time zone.
abstract interface class DayWindowCalculator {
  DayWindow forDate(int year, int month, int day);
  DayWindow containing(DateTime instantUtc);
  DayWindow next(DayWindow window);
  DayWindow previous(DayWindow window);
}

/// Uses the device's local zone, which is what the user sees (SPEC §5.3).
class LocalDayWindowCalculator implements DayWindowCalculator {
  const LocalDayWindowCalculator();

  @override
  DayWindow forDate(int year, int month, int day) {
    // DateTime's local arithmetic already accounts for DST, so a transition day
    // comes out as 23 or 25 hours without special-casing.
    final localMidnight = DateTime(year, month, day);
    final nextMidnight = DateTime(year, month, day + 1);
    return DayWindow(
      startUtc: localMidnight.toUtc(),
      endUtc: nextMidnight.toUtc(),
      year: year,
      month: month,
      day: day,
    );
  }

  @override
  DayWindow containing(DateTime instantUtc) {
    final local = instantUtc.toLocal();
    return forDate(local.year, local.month, local.day);
  }

  @override
  DayWindow next(DayWindow window) =>
      containing(window.endUtc.add(const Duration(minutes: 1)));

  @override
  DayWindow previous(DayWindow window) =>
      containing(window.startUtc.subtract(const Duration(minutes: 1)));
}

/// A calculator with hand-made windows, for tests that need a specific day
/// length (DST) without depending on the host zone.
class FixedDayWindowCalculator implements DayWindowCalculator {
  FixedDayWindowCalculator(this.windows);

  final List<DayWindow> windows;

  @override
  DayWindow forDate(int year, int month, int day) => windows.firstWhere(
    (w) => w.year == year && w.month == month && w.day == day,
    orElse: () => throw ArgumentError('no window for $year-$month-$day'),
  );

  @override
  DayWindow containing(DateTime instantUtc) => windows.firstWhere(
    (w) => w.contains(instantUtc),
    orElse: () => throw ArgumentError('no window contains $instantUtc'),
  );

  @override
  DayWindow next(DayWindow window) => windows[windows.indexOf(window) + 1];

  @override
  DayWindow previous(DayWindow window) => windows[windows.indexOf(window) - 1];
}
