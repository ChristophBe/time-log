import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/palette.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/continue_rule.dart';
import '../../domain/timeline_writer.dart';
import 'action_feedback.dart';
import 'running_card.dart';
import 'start_sheet.dart';
import 'today_providers.dart';

/// The home screen (SPEC §8.1): what is running, one tap to start the next
/// thing, and the day below it.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.isoDate});

  final String? isoDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(dayEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _start(context, ref),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start'),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DatabaseError(error: error),
        data: (entries) => Column(
          children: <Widget>[
            RunningCard(
              onStop: () => _stop(context, ref),
              onResumeLast: () => _resumeLast(context, ref),
              onFixStart: () => _openSettings(context),
            ),
            Expanded(child: _DayEntryList(entries: entries)),
            const _DayTotalsFooter(),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) => context.push('/settings');

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final request = await showStartSheet(context);
    if (request == null || !context.mounted) return;
    final outcome = await ref
        .read(timelineWriterProvider)
        .startByName(name: request.name, note: request.note);
    if (!context.mounted) return;
    showStartFeedback(context, outcome);
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final outcome = await ref.read(timelineWriterProvider).stop();
    if (!context.mounted || !outcome.stopped) return;
    showUndoableFeedback(
      context,
      message:
          'Stopped ${outcome.activityName} after '
          '${formatDurationVerbose(outcome.duration!)}',
      undo: outcome.undo,
      // Under a minute, the likelier intent is "that was a mistake", so offer
      // Discard in place of Undo (SPEC §6.2).
      extraAction: outcome.wasVeryShort
          ? SnackBarAction(
              label: 'Discard',
              onPressed: () =>
                  ref.read(timelineWriterProvider).delete(outcome.entryId!),
            )
          : null,
    );
  }

  Future<void> _resumeLast(BuildContext context, WidgetRef ref) async {
    final last = ref.read(lastFinishedEntryProvider).value;
    if (last == null) return;
    await resumeOrContinue(context, ref, last);
  }
}

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

Future<_ResumeChoice?> _askContinueOrNew(BuildContext context) =>
    showDialog<_ResumeChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continue or start new?'),
        content: const Text(
          'This entry ended moments ago. Continuing extends it instead of '
          'creating a second entry next to it.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ResumeChoice.startNew),
            child: const Text('Start new'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_ResumeChoice.continueEntry),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

/// A plain chronological list of the day. P2 replaces this with the calendar.
class _DayEntryList extends ConsumerWidget {
  const _DayEntryList({required this.entries});

  final List<TimeEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return const Center(child: Text('No entries for this day'));
    }
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final activity = activities[entry.activityId];
        final colors = ActivityPalette.forSeed(
          activity?.colorSeed ?? 0,
          Theme.of(context).brightness,
        );
        return ListTile(
          leading: Container(
            width: 16,
            height: 40,
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Text(activity?.name ?? 'Activity'),
          subtitle: Text(
            '${formatTimeOfDay(entry.startUtc.toLocal(), use24h: settings.use24HourClock)}'
            ' - '
            '${entry.endUtc == null ? 'now' : formatTimeOfDay(entry.endUtc!.toLocal(), use24h: settings.use24HourClock)}',
          ),
          trailing: IconButton(
            tooltip: 'Resume ${activity?.name ?? 'activity'}',
            icon: const Icon(Icons.play_arrow),
            onPressed: () => resumeOrContinue(context, ref, entry),
          ),
        );
      },
    );
  }
}

class _DayTotalsFooter extends ConsumerWidget {
  const _DayTotalsFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(dayTotalsProvider);
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final top = totals.rankedActivityIds.take(3).toList();

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Tracked ${formatDurationCompact(totals.tracked)}'
              '  -  untracked ${formatDurationCompact(totals.untracked)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (top.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  top
                      .map(
                        (id) =>
                            '${activities[id]?.name ?? 'Activity'} '
                            '${formatDurationCompact(totals.byActivityId[id]!)}',
                      )
                      .join('  -  '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// SPEC §9.5: a database failure explains itself rather than showing an empty
/// timeline, which would read as data loss.
class _DatabaseError extends StatelessWidget {
  const _DatabaseError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Your time log could not be opened.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
