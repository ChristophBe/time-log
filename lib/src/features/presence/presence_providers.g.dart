// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The selected day's active sessions, oldest first (SPEC §9.9).

@ProviderFor(daySessions)
final daySessionsProvider = DaySessionsProvider._();

/// The selected day's active sessions, oldest first (SPEC §9.9).

final class DaySessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ActiveSession>>,
          List<ActiveSession>,
          Stream<List<ActiveSession>>
        >
    with
        $FutureModifier<List<ActiveSession>>,
        $StreamProvider<List<ActiveSession>> {
  /// The selected day's active sessions, oldest first (SPEC §9.9).
  DaySessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'daySessionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$daySessionsHash();

  @$internal
  @override
  $StreamProviderElement<List<ActiveSession>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ActiveSession>> create(Ref ref) {
    return daySessions(ref);
  }
}

String _$daySessionsHash() => r'7783ae3318d4853f1bfb4749371956b08d04dfee';

/// The selected day's active total, or null on a day without any sessions, so
/// the header can leave it out altogether (SPEC §8.1).
///
/// On the same 30-second tick as the tracked total beside it.

@ProviderFor(activeTotal)
final activeTotalProvider = ActiveTotalProvider._();

/// The selected day's active total, or null on a day without any sessions, so
/// the header can leave it out altogether (SPEC §8.1).
///
/// On the same 30-second tick as the tracked total beside it.

final class ActiveTotalProvider
    extends $FunctionalProvider<Duration?, Duration?, Duration?>
    with $Provider<Duration?> {
  /// The selected day's active total, or null on a day without any sessions, so
  /// the header can leave it out altogether (SPEC §8.1).
  ///
  /// On the same 30-second tick as the tracked total beside it.
  ActiveTotalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeTotalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeTotalHash();

  @$internal
  @override
  $ProviderElement<Duration?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration? create(Ref ref) {
    return activeTotal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration?>(value),
    );
  }
}

String _$activeTotalHash() => r'491cc8bce271c2ed12e05f071c1794d0a781c671';

/// Asked again whenever the setting changes, once the change has landed.

@ProviderFor(loginItemStatus)
final loginItemStatusProvider = LoginItemStatusProvider._();

/// Asked again whenever the setting changes, once the change has landed.

final class LoginItemStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<LoginItemStatus>,
          LoginItemStatus,
          FutureOr<LoginItemStatus>
        >
    with $FutureModifier<LoginItemStatus>, $FutureProvider<LoginItemStatus> {
  /// Asked again whenever the setting changes, once the change has landed.
  LoginItemStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginItemStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginItemStatusHash();

  @$internal
  @override
  $FutureProviderElement<LoginItemStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LoginItemStatus> create(Ref ref) {
    return loginItemStatus(ref);
  }
}

String _$loginItemStatusHash() => r'4cdf768245141a3cc450729a37bfd25f26733b91';
