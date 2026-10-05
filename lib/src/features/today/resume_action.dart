import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/adaptive.dart';
import '../../core/clock.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/continue_rule.dart';
import '../../domain/timeline_writer.dart';
import 'action_feedback.dart';
import 'today_providers.dart';

/// Resume creates a new entry; Continue reopens the most recent one when it
/// ended moments ago (SPEC §6.3, §6.4).
Future<void> resumeOrContinue(
  BuildContext context,
  WidgetRef ref,
  TimeEntry entry,
) async {
  final writer = ref.read(timelineWriterProvider);
  final settings = ref.read(appSettingsProvider).value ?? const AppSettings();
  final now = ref.read(appClockProvider).nowUtc();
  final lastFinished = await ref.read(lastFinishedEntryProvider.future);
  final running = ref.read(runningEntryProvider).value;

  final canContinue = canContinueEntry(
    entry: entry,
    lastFinished: lastFinished,
    running: running,
    now: now,
    window: settings.continueWindow,
  );

  if (canContinue && context.mounted) {
    final choice = await _askContinueOrNew(context);
    if (choice == null || !context.mounted) return;
    if (choice == _ResumeChoice.continueEntry) {
      final undo = await writer.continueEntry(
        entry.id,
        window: settings.continueWindow,
      );
      if (!context.mounted) return;
      showUndoableFeedback(context, message: 'Continued', undo: undo);
      return;
    }
  }

  final outcome = await writer.resume(entry.id);
  if (!context.mounted) return;
  showStartFeedback(context, outcome);
}

enum _ResumeChoice { continueEntry, startNew }

/// Adaptive: a Material dialog, or a `CupertinoAlertDialog` on Apple platforms
/// (SPEC §9.8). Continue is the default action either way (SPEC §6.4).
Future<_ResumeChoice?> _askContinueOrNew(BuildContext context) =>
    showAdaptiveDialog<_ResumeChoice>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Continue or start new?'),
        content: const Text(
          'This entry ended moments ago. Continuing extends it instead of '
          'creating a second entry next to it.',
        ),
        actions: <Widget>[
          adaptiveAction(
            context: context,
            onPressed: () => Navigator.of(context).pop(_ResumeChoice.startNew),
            child: const Text('Start new'),
          ),
          adaptiveAction(
            context: context,
            isDefault: true,
            onPressed: () =>
                Navigator.of(context).pop(_ResumeChoice.continueEntry),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
