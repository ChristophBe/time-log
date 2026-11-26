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

/// Activities ranked against what has been typed (SPEC §9.6), for every place
/// an activity name is entered.
///
/// [excludeActivityId] is the one activity that would be a no-op to pick: the
/// running one when starting, the entry's own when relabelling it. Null where
/// every activity is a fair answer.

@ProviderFor(activityInputSuggestions)
final activityInputSuggestionsProvider = ActivityInputSuggestionsFamily._();

/// Activities ranked against what has been typed (SPEC §9.6), for every place
/// an activity name is entered.
///
/// [excludeActivityId] is the one activity that would be a no-op to pick: the
/// running one when starting, the entry's own when relabelling it. Null where
/// every activity is a fair answer.

final class ActivityInputSuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ActivitySuggestion>>,
          List<ActivitySuggestion>,
          Stream<List<ActivitySuggestion>>
        >
    with
        $FutureModifier<List<ActivitySuggestion>>,
        $StreamProvider<List<ActivitySuggestion>> {
  /// Activities ranked against what has been typed (SPEC §9.6), for every place
  /// an activity name is entered.
  ///
  /// [excludeActivityId] is the one activity that would be a no-op to pick: the
  /// running one when starting, the entry's own when relabelling it. Null where
  /// every activity is a fair answer.
  ActivityInputSuggestionsProvider._({
    required ActivityInputSuggestionsFamily super.from,
    required (String, String?) super.argument,
  }) : super(
         retry: null,
         name: r'activityInputSuggestionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activityInputSuggestionsHash();

  @override
  String toString() {
    return r'activityInputSuggestionsProvider'
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
    final argument = this.argument as (String, String?);
    return activityInputSuggestions(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityInputSuggestionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activityInputSuggestionsHash() =>
    r'fd083d27e990956e10333ddbd442eb911d0ae2fb';

/// Activities ranked against what has been typed (SPEC §9.6), for every place
/// an activity name is entered.
///
/// [excludeActivityId] is the one activity that would be a no-op to pick: the
/// running one when starting, the entry's own when relabelling it. Null where
/// every activity is a fair answer.

final class ActivityInputSuggestionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<ActivitySuggestion>>,
          (String, String?)
        > {
  ActivityInputSuggestionsFamily._()
    : super(
        retry: null,
        name: r'activityInputSuggestionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Activities ranked against what has been typed (SPEC §9.6), for every place
  /// an activity name is entered.
  ///
  /// [excludeActivityId] is the one activity that would be a no-op to pick: the
  /// running one when starting, the entry's own when relabelling it. Null where
  /// every activity is a fair answer.

  ActivityInputSuggestionsProvider call(
    String query,
    String? excludeActivityId,
  ) => ActivityInputSuggestionsProvider._(
    argument: (query, excludeActivityId),
    from: this,
  );

  @override
  String toString() => r'activityInputSuggestionsProvider';
}
