import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/timeline_writer.dart';
import 'today_providers.dart';

part 'day_rollover.g.dart';

/// Runs SPEC §6.11 whenever the app gets a chance to notice that a midnight has
/// passed: at launch, on resume, and on the 30-second tick (SPEC §9.3).
///
/// A named provider rather than a `listen` buried in a widget, for two reasons.
/// It is the only place the app writes to the timeline without being asked, so
/// it should be findable; and a test can call [check] instead of waiting out a
/// timer, which widget tests cannot do anyway -- both tickers are overridden
/// with single-value streams there.
///
/// The state is the last midnight that was cut at, which is of no interest to
/// the UI and a great deal of interest to a test.
@Riverpod(keepAlive: true)
class DayRollover extends _$DayRollover {
  Future<void>? _inFlight;

  @override
  DateTime? build() => null;

  /// Cuts the running entry at any midnight it has crossed (SPEC §6.11), then
  /// lets the day view follow the real day (SPEC §8.2).
  ///
  /// The day is moved whether or not anything was cut: a midnight that passes
  /// with nothing running still has to move the date on the header.
  Future<void> check() =>
      _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    // Launch, resume and the tick can arrive together -- waking a laptop fires
    // all three. The pass is idempotent, so this is about not doing the same
    // database work three times rather than about correctness.
    final outcome = await ref
        .read(timelineWriterProvider)
        .rollOverRunningEntry(days: ref.read(dayWindowsProvider));
    if (outcome.changedAnything) state = outcome.boundaries.last;
    ref.read(selectedDayProvider.notifier).followNow();
  }
}
