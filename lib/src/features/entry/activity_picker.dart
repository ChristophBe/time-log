import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline_writer.dart';
import '../today/action_feedback.dart';
import 'activity_editor.dart';
import 'activity_name_sheet.dart';

/// Changes which activity one entry belongs to (SPEC §6.10).
///
/// The question is the shared one ("what was this?") asked about a span that
/// has already happened, so it is [showActivityNameSheet]: a name field over
/// the §9.6 suggestions, without the entry's own activity, since picking that
/// would be a no-op. Typing a name nothing matches creates it, so creating is
/// never a mode (SPEC §8.3).
///
/// Renaming the activity for *all* history (SPEC §6.7) is the footer row rather
/// than the headline. Both edits start from the same tap on the entry sheet, and
/// this is the one that is usually meant; the other one is a step further in and
/// says what it will touch.
///
/// Returns the activity the entry now belongs to, or null when it was not
/// relabelled, so the caller can react to the change.
Future<Activity?> showActivityPicker(
  BuildContext context,
  WidgetRef ref, {
  required TimeEntry entry,
  required Activity current,
}) async {
  final name = await showActivityNameSheet(
    context,
    title: 'Change activity',
    subtitle: 'This entry only — currently ${current.name}.',
    commitLabel: 'Change activity',
    excludeActivityId: current.id,
    footer: (sheetContext) => TextButton.icon(
      key: const Key('activity-picker-rename'),
      onPressed: () {
        Navigator.of(sheetContext).pop();
        showActivityEditor(context, ref, current);
      },
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: Text(
        'Rename or recolour “${current.name}” everywhere…',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
  if (name == null || !context.mounted) return null;

  final result = await ref
      .read(timelineWriterProvider)
      .setEntryActivity(entryId: entry.id, name: name);
  final undo = result.undo;
  // Nothing was written, so there is nothing to announce and nothing for the
  // entry sheet to close over (SPEC §6.10).
  if (undo == null) return null;
  if (context.mounted) {
    showUndoableFeedback(
      context,
      message: 'Changed to ${result.activity.name}',
      undo: undo,
    );
  }
  return result.activity;
}
