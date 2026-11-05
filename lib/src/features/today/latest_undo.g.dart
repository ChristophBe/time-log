// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'latest_undo.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Undo the last SnackBar offered, kept for the rest of the session so the
/// entry sheet's overflow menu can still offer it after the eight seconds are
/// up (SPEC §7.5).
///
/// Only ever the latest one, and replaced by whatever the next SnackBar says —
/// including a SnackBar with no Undo at all, such as a refused edit. An older
/// token restores snapshots from before something newer happened, so offering
/// it would be offering to undo the newer thing too. For the same reason the
/// midnight cut (SPEC §6.11), which writes without a SnackBar, clears it.

@ProviderFor(LatestUndo)
final latestUndoProvider = LatestUndoProvider._();

/// The Undo the last SnackBar offered, kept for the rest of the session so the
/// entry sheet's overflow menu can still offer it after the eight seconds are
/// up (SPEC §7.5).
///
/// Only ever the latest one, and replaced by whatever the next SnackBar says —
/// including a SnackBar with no Undo at all, such as a refused edit. An older
/// token restores snapshots from before something newer happened, so offering
/// it would be offering to undo the newer thing too. For the same reason the
/// midnight cut (SPEC §6.11), which writes without a SnackBar, clears it.
final class LatestUndoProvider
    extends $NotifierProvider<LatestUndo, UndoToken?> {
  /// The Undo the last SnackBar offered, kept for the rest of the session so the
  /// entry sheet's overflow menu can still offer it after the eight seconds are
  /// up (SPEC §7.5).
  ///
  /// Only ever the latest one, and replaced by whatever the next SnackBar says —
  /// including a SnackBar with no Undo at all, such as a refused edit. An older
  /// token restores snapshots from before something newer happened, so offering
  /// it would be offering to undo the newer thing too. For the same reason the
  /// midnight cut (SPEC §6.11), which writes without a SnackBar, clears it.
  LatestUndoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestUndoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestUndoHash();

  @$internal
  @override
  LatestUndo create() => LatestUndo();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UndoToken? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UndoToken?>(value),
    );
  }
}

String _$latestUndoHash() => r'd50ef8030a77c053ac43d7fdc4aecbff143bd325';

/// The Undo the last SnackBar offered, kept for the rest of the session so the
/// entry sheet's overflow menu can still offer it after the eight seconds are
/// up (SPEC §7.5).
///
/// Only ever the latest one, and replaced by whatever the next SnackBar says —
/// including a SnackBar with no Undo at all, such as a refused edit. An older
/// token restores snapshots from before something newer happened, so offering
/// it would be offering to undo the newer thing too. For the same reason the
/// midnight cut (SPEC §6.11), which writes without a SnackBar, clears it.

abstract class _$LatestUndo extends $Notifier<UndoToken?> {
  UndoToken? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UndoToken?, UndoToken?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UndoToken?, UndoToken?>,
              UndoToken?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
