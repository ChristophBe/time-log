// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_rollover.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(DayRollover)
final dayRolloverProvider = DayRolloverProvider._();

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
final class DayRolloverProvider
    extends $NotifierProvider<DayRollover, DateTime?> {
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
  DayRolloverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayRolloverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayRolloverHash();

  @$internal
  @override
  DayRollover create() => DayRollover();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
    );
  }
}

String _$dayRolloverHash() => r'ea31850c182c62b131cf0df8d06f439b0faf3f55';

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

abstract class _$DayRollover extends $Notifier<DateTime?> {
  DateTime? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime?, DateTime?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime?, DateTime?>,
              DateTime?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
