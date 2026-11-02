import 'package:flutter/material.dart';

import '../../app/adaptive.dart';
import '../../core/formatters.dart';

/// Asks whether a neighbour should follow a boundary moved away from it
/// (SPEC §7.1).
///
/// Returns true to adjust the neighbour, false to leave the gap, and null when
/// the edit was cancelled, which includes dismissing the dialog: a dismissal
/// has not answered the question, so it must not change anything.
///
/// Adaptive: a Material dialog, or a `CupertinoAlertDialog` on Apple platforms
/// (SPEC §9.8).
Future<bool?> askAdjustNeighbour(
  BuildContext context, {
  required String? neighbourName,
  required Duration gap,
}) {
  final name = neighbourName ?? 'the neighbouring entry';
  return showAdaptiveDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog.adaptive(
      title: Text('Also adjust $name?'),
      content: Text(
        'This would leave ${formatDuration(gap)} untracked next to $name. '
        'Adjusting it keeps the two entries touching.',
      ),
      actions: <Widget>[
        adaptiveAction(
          context: context,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        adaptiveAction(
          context: context,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Leave gap'),
        ),
        adaptiveAction(
          context: context,
          isDefault: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Adjust $name'),
        ),
      ],
    ),
  );
}
