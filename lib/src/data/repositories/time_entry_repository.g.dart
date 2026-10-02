// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_entry_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(timeEntryRepository)
final timeEntryRepositoryProvider = TimeEntryRepositoryProvider._();

final class TimeEntryRepositoryProvider
    extends
        $FunctionalProvider<
          TimeEntryRepository,
          TimeEntryRepository,
          TimeEntryRepository
        >
    with $Provider<TimeEntryRepository> {
  TimeEntryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timeEntryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timeEntryRepositoryHash();

  @$internal
  @override
  $ProviderElement<TimeEntryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TimeEntryRepository create(Ref ref) {
    return timeEntryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeEntryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeEntryRepository>(value),
    );
  }
}

String _$timeEntryRepositoryHash() =>
    r'61efd760074a2144770d666176eee4827bb6bcfc';
