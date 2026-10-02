// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appClock)
final appClockProvider = AppClockProvider._();

final class AppClockProvider
    extends $FunctionalProvider<AppClock, AppClock, AppClock>
    with $Provider<AppClock> {
  AppClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appClockHash();

  @$internal
  @override
  $ProviderElement<AppClock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppClock create(Ref ref) {
    return appClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppClock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppClock>(value),
    );
  }
}

String _$appClockHash() => r'fbbe189ccb6cd6778b4b02cced63c518e6b55c93';

/// Ticks once a second. Scoped to the running card's elapsed text only, so a
/// per-second rebuild never reaches the calendar (SPEC §11.4).

@ProviderFor(secondTicker)
final secondTickerProvider = SecondTickerProvider._();

/// Ticks once a second. Scoped to the running card's elapsed text only, so a
/// per-second rebuild never reaches the calendar (SPEC §11.4).

final class SecondTickerProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// Ticks once a second. Scoped to the running card's elapsed text only, so a
  /// per-second rebuild never reaches the calendar (SPEC §11.4).
  SecondTickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secondTickerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secondTickerHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return secondTicker(ref);
  }
}

String _$secondTickerHash() => r'8543f7ca1ac72f0d898c6388ddaf3453e4f5dcc0';

/// Ticks every 30 seconds, for the now-line and the day view.

@ProviderFor(coarseTicker)
final coarseTickerProvider = CoarseTickerProvider._();

/// Ticks every 30 seconds, for the now-line and the day view.

final class CoarseTickerProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// Ticks every 30 seconds, for the now-line and the day view.
  CoarseTickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coarseTickerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coarseTickerHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return coarseTicker(ref);
  }
}

String _$coarseTickerHash() => r'22eac7ea047f5148e5cee72b748ee6444f5795b2';
