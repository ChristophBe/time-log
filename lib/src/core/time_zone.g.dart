// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_zone.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(timeZoneResolver)
final timeZoneResolverProvider = TimeZoneResolverProvider._();

final class TimeZoneResolverProvider
    extends
        $FunctionalProvider<
          TimeZoneResolver,
          TimeZoneResolver,
          TimeZoneResolver
        >
    with $Provider<TimeZoneResolver> {
  TimeZoneResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timeZoneResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timeZoneResolverHash();

  @$internal
  @override
  $ProviderElement<TimeZoneResolver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TimeZoneResolver create(Ref ref) {
    return timeZoneResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeZoneResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeZoneResolver>(value),
    );
  }
}

String _$timeZoneResolverHash() => r'4537b14ae23fee9903671a35e3ce3fb5b677ed31';

/// Resolved once and cached: the zone does not change mid-session often enough
/// to justify asking the platform on every write.

@ProviderFor(currentTimeZone)
final currentTimeZoneProvider = CurrentTimeZoneProvider._();

/// Resolved once and cached: the zone does not change mid-session often enough
/// to justify asking the platform on every write.

final class CurrentTimeZoneProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Resolved once and cached: the zone does not change mid-session often enough
  /// to justify asking the platform on every write.
  CurrentTimeZoneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTimeZoneProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTimeZoneHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return currentTimeZone(ref);
  }
}

String _$currentTimeZoneHash() => r'8b2741fa7aff7105369af02fb61e601a6bd98777';
