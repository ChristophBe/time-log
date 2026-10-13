import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/activity.dart';
import '../../domain/timeline_writer.dart';
import 'action_feedback.dart';

/// Starts [name] now, stopping whatever is running at the same instant
/// (SPEC §6.1).
///
/// Deliberately the whole of "start" outside the widget that triggered it, so
/// the composer, the keyboard shortcut and -- later -- a notification action or
/// a tray item all take the identical path (SPEC §13 P5).
Future<void> startActivityNamed(
  BuildContext context,
  WidgetRef ref,
  String name,
) async {
  // Invalid names are swallowed rather than reported: the only way to get here
  // with one is an empty field, and an error for pressing Start on nothing
  // would be noise.
  if (!Activity.isValidName(name)) return;
  final outcome = await ref
      .read(timelineWriterProvider)
      .startByName(name: name);
  if (!context.mounted) return;
  showStartFeedback(context, outcome);
}
