import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../domain/timeline_writer.dart';

/// Length of the undo window (SPEC §7.5).
const Duration kUndoWindow = Duration(seconds: 8);

/// Announces [message] to assistive technology and shows it with an Undo
/// action.
///
/// Announcing on every committed change is SPEC §10.4; the SnackBar carrying
/// Undo rather than a confirmation dialog is SPEC §6.1 -- the undo is what makes
/// a destructive-looking action safe enough to need no confirmation.
void showUndoableFeedback(
  BuildContext context, {
  required String message,
  required UndoToken? undo,
  SnackBarAction? extraAction,
}) {
  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: kUndoWindow,
      // Explicit, because `SnackBar.persist` defaults to `action != null`:
      // without this, every SnackBar that carries an Undo would ignore its own
      // duration and sit on the screen until it was tapped or dismissed. The
      // undo window is eight seconds and then the offer is gone (SPEC §7.5) --
      // and on Today the bar sits directly over the start composer, which has
      // to be reachable at any moment (SPEC §8.1).
      persist: false,
      action:
          extraAction ??
          (undo == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => _undo(messenger, undo),
                )),
    ),
  );
}

void _undo(ScaffoldMessengerState messenger, UndoToken undo) {
  undo.undo().catchError((Object error) {
    // The timeline moved on (something else is running now), so the inverse no
    // longer applies. Say so rather than failing silently.
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not undo: the timeline has changed')),
    );
  });
}

/// Feedback for a start/switch/resume (SPEC §6.1, §6.3).
void showStartFeedback(BuildContext context, StartOutcome outcome) {
  final message = switch (outcome.mode) {
    StartMode.started => 'Started ${outcome.activityName}',
    StartMode.switched =>
      'Started ${outcome.activityName}, stopped ${outcome.stoppedActivityName}',
    StartMode.replacedMisstart =>
      'Started ${outcome.activityName} instead of ${outcome.stoppedActivityName}',
    StartMode.alreadyRunning => '${outcome.activityName} is already running',
  };
  showUndoableFeedback(context, message: message, undo: outcome.undo);
}
