// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Calendar zoom in pixels per hour (SPEC §8.2). Starts from the stored setting
/// and is adjusted by pinch or the zoom buttons for the session.

@ProviderFor(CalendarZoom)
final calendarZoomProvider = CalendarZoomProvider._();

/// Calendar zoom in pixels per hour (SPEC §8.2). Starts from the stored setting
/// and is adjusted by pinch or the zoom buttons for the session.
final class CalendarZoomProvider
    extends $NotifierProvider<CalendarZoom, double> {
  /// Calendar zoom in pixels per hour (SPEC §8.2). Starts from the stored setting
  /// and is adjusted by pinch or the zoom buttons for the session.
  CalendarZoomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarZoomProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarZoomHash();

  @$internal
  @override
  CalendarZoom create() => CalendarZoom();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$calendarZoomHash() => r'ee06e340355f3478993d5c3518ca0db55c5a655c';

/// Calendar zoom in pixels per hour (SPEC §8.2). Starts from the stored setting
/// and is adjusted by pinch or the zoom buttons for the session.

abstract class _$CalendarZoom extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Recomputed on the 30-second tick, not every second (SPEC §11.4).

@ProviderFor(dayTimeline)
final dayTimelineProvider = DayTimelineProvider._();

/// Recomputed on the 30-second tick, not every second (SPEC §11.4).

final class DayTimelineProvider
    extends $FunctionalProvider<DayTimeline, DayTimeline, DayTimeline>
    with $Provider<DayTimeline> {
  /// Recomputed on the 30-second tick, not every second (SPEC §11.4).
  DayTimelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayTimelineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayTimelineHash();

  @$internal
  @override
  $ProviderElement<DayTimeline> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DayTimeline create(Ref ref) {
    return dayTimeline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayTimeline value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayTimeline>(value),
    );
  }
}

String _$dayTimelineHash() => r'697a3213ce81ca9d35b2a58b1393c0968eea8c23';

@ProviderFor(calendarMetrics)
final calendarMetricsProvider = CalendarMetricsProvider._();

final class CalendarMetricsProvider
    extends
        $FunctionalProvider<CalendarMetrics, CalendarMetrics, CalendarMetrics>
    with $Provider<CalendarMetrics> {
  CalendarMetricsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarMetricsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarMetricsHash();

  @$internal
  @override
  $ProviderElement<CalendarMetrics> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CalendarMetrics create(Ref ref) {
    return calendarMetrics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarMetrics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarMetrics>(value),
    );
  }
}

String _$calendarMetricsHash() => r'2ad8d2ade3aa7fc229e831065fa68ac856de6a4a';
