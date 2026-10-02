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
