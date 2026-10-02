import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// The only source of "now" in the app.
///
/// Everything that needs the current time takes an [AppClock] (or is handed a
/// `now` parameter). `DateTime.now()` must not appear anywhere else in `lib/` --
/// `test/architecture_test.dart` enforces that. This is what makes the timeline
/// invariants in SPEC §4 and the DST behaviour in §5.3 testable.
abstract interface class AppClock {
  /// The current instant, always in UTC. The app stores UTC (SPEC §5.3) and
  /// converts to local only for display.
  DateTime nowUtc();
}

class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// A clock tests drive by hand.
class FakeClock implements AppClock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  void advance(Duration by) => _now = _now.add(by);
  void setTo(DateTime instant) => _now = instant.toUtc();
}

@Riverpod(keepAlive: true)
AppClock appClock(Ref ref) => const SystemClock();

/// Ticks once a second. Scoped to the running card's elapsed text only, so a
/// per-second rebuild never reaches the calendar (SPEC §11.4).
@riverpod
Stream<DateTime> secondTicker(Ref ref) =>
    _ticker(ref, const Duration(seconds: 1));

/// Ticks every 30 seconds, for the now-line and the day view.
@riverpod
Stream<DateTime> coarseTicker(Ref ref) =>
    _ticker(ref, const Duration(seconds: 30));

Stream<DateTime> _ticker(Ref ref, Duration interval) {
  final clock = ref.watch(appClockProvider);
  final controller = StreamController<DateTime>();
  controller.add(clock.nowUtc());
  final timer = Timer.periodic(interval, (_) => controller.add(clock.nowUtc()));
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
}
