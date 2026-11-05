import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/timeline_writer.dart';

part 'latest_undo.g.dart';

/// The Undo the last SnackBar offered, kept for the rest of the session so the
/// entry sheet's overflow menu can still offer it after the eight seconds are
/// up (SPEC §7.5).
///
/// Only ever the latest one, and replaced by whatever the next SnackBar says —
/// including a SnackBar with no Undo at all, such as a refused edit. An older
/// token restores snapshots from before something newer happened, so offering
/// it would be offering to undo the newer thing too. For the same reason the
/// midnight cut (SPEC §6.11), which writes without a SnackBar, clears it.
@Riverpod(keepAlive: true)
class LatestUndo extends _$LatestUndo {
  @override
  UndoToken? build() => null;

  // ignore: use_setters_to_change_properties
  void offer(UndoToken? undo) => state = undo;

  /// Forgets [undo] once it has been used, unless something newer has already
  /// replaced it.
  void spend(UndoToken undo) {
    if (identical(state, undo)) state = null;
  }
}
