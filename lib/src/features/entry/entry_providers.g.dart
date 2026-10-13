// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The entries on either side of [entryId], which decide whether a boundary is
/// shared or free (SPEC §7.1) and what a typed time would collide with.

@ProviderFor(entryNeighbours)
final entryNeighboursProvider = EntryNeighboursFamily._();

/// The entries on either side of [entryId], which decide whether a boundary is
/// shared or free (SPEC §7.1) and what a typed time would collide with.

final class EntryNeighboursProvider
    extends
        $FunctionalProvider<
          AsyncValue<EntryNeighbours>,
          EntryNeighbours,
          FutureOr<EntryNeighbours>
        >
    with $FutureModifier<EntryNeighbours>, $FutureProvider<EntryNeighbours> {
  /// The entries on either side of [entryId], which decide whether a boundary is
  /// shared or free (SPEC §7.1) and what a typed time would collide with.
  EntryNeighboursProvider._({
    required EntryNeighboursFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'entryNeighboursProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$entryNeighboursHash();

  @override
  String toString() {
    return r'entryNeighboursProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EntryNeighbours> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EntryNeighbours> create(Ref ref) {
    final argument = this.argument as String;
    return entryNeighbours(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EntryNeighboursProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$entryNeighboursHash() => r'0f3a8ba827118a499770948c32cfc9fd00fef0c3';

/// The entries on either side of [entryId], which decide whether a boundary is
/// shared or free (SPEC §7.1) and what a typed time would collide with.

final class EntryNeighboursFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EntryNeighbours>, String> {
  EntryNeighboursFamily._()
    : super(
        retry: null,
        name: r'entryNeighboursProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The entries on either side of [entryId], which decide whether a boundary is
  /// shared or free (SPEC §7.1) and what a typed time would collide with.

  EntryNeighboursProvider call(String entryId) =>
      EntryNeighboursProvider._(argument: entryId, from: this);

  @override
  String toString() => r'entryNeighboursProvider';
}

/// Activities ranked for relabelling one entry (SPEC §6.10, §9.6).
///
/// The same ranking the start composer uses, excluding a different activity:
/// there, picking the running one would be a no-op; here it is the entry's
/// current one.

@ProviderFor(relabelSuggestions)
final relabelSuggestionsProvider = RelabelSuggestionsFamily._();

/// Activities ranked for relabelling one entry (SPEC §6.10, §9.6).
///
/// The same ranking the start composer uses, excluding a different activity:
/// there, picking the running one would be a no-op; here it is the entry's
/// current one.

final class RelabelSuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ActivitySuggestion>>,
          List<ActivitySuggestion>,
          Stream<List<ActivitySuggestion>>
        >
    with
        $FutureModifier<List<ActivitySuggestion>>,
        $StreamProvider<List<ActivitySuggestion>> {
  /// Activities ranked for relabelling one entry (SPEC §6.10, §9.6).
  ///
  /// The same ranking the start composer uses, excluding a different activity:
  /// there, picking the running one would be a no-op; here it is the entry's
  /// current one.
  RelabelSuggestionsProvider._({
    required RelabelSuggestionsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'relabelSuggestionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$relabelSuggestionsHash();

  @override
  String toString() {
    return r'relabelSuggestionsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<ActivitySuggestion>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ActivitySuggestion>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return relabelSuggestions(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is RelabelSuggestionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$relabelSuggestionsHash() =>
    r'651994075f4eea39c1a7b849d06b3f724aafd0b7';

/// Activities ranked for relabelling one entry (SPEC §6.10, §9.6).
///
/// The same ranking the start composer uses, excluding a different activity:
/// there, picking the running one would be a no-op; here it is the entry's
/// current one.

final class RelabelSuggestionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<ActivitySuggestion>>,
          (String, String)
        > {
  RelabelSuggestionsFamily._()
    : super(
        retry: null,
        name: r'relabelSuggestionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Activities ranked for relabelling one entry (SPEC §6.10, §9.6).
  ///
  /// The same ranking the start composer uses, excluding a different activity:
  /// there, picking the running one would be a no-op; here it is the entry's
  /// current one.

  RelabelSuggestionsProvider call(String excludeActivityId, String query) =>
      RelabelSuggestionsProvider._(
        argument: (excludeActivityId, query),
        from: this,
      );

  @override
  String toString() => r'relabelSuggestionsProvider';
}
