// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activeSessionRepository)
final activeSessionRepositoryProvider = ActiveSessionRepositoryProvider._();

final class ActiveSessionRepositoryProvider
    extends
        $FunctionalProvider<
          ActiveSessionRepository,
          ActiveSessionRepository,
          ActiveSessionRepository
        >
    with $Provider<ActiveSessionRepository> {
  ActiveSessionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSessionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSessionRepositoryHash();

  @$internal
  @override
  $ProviderElement<ActiveSessionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActiveSessionRepository create(Ref ref) {
    return activeSessionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveSessionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveSessionRepository>(value),
    );
  }
}

String _$activeSessionRepositoryHash() =>
    r'563bb0d12aeb2f58da5f7615a8cf38c5e95a6d40';
