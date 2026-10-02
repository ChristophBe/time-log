import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline_writer.dart';
import '../calendar/calendar_providers.dart';
import '../calendar/day_calendar.dart';
import '../calendar/day_navigation_bar.dart';
import '../entry/entry_sheet.dart';
import 'resume_action.dart';
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

    return CallbackShortcuts(
      // SPEC §10.5. The block-focused shortcuts live on the blocks themselves.
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            ref.read(selectedDayProvider.notifier).previousDay(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            ref.read(selectedDayProvider.notifier).nextDay(),
        const SingleActivator(LogicalKeyboardKey.keyT): () =>
            ref.read(selectedDayProvider.notifier).today(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _start(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            _start(context, ref),
        const SingleActivator(LogicalKeyboardKey.period, control: true): () =>
            _stop(context, ref),
        const SingleActivator(LogicalKeyboardKey.period, meta: true): () =>
            _stop(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            _resumeLast(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            _resumeLast(context, ref),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('time-log'),
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
            data: (_) => Column(
              children: <Widget>[
                RunningCard(
                  onStop: () => _stop(context, ref),
                  onResumeLast: () => _resumeLast(context, ref),
                  onFixStart: () => _openSettings(context),
                ),
                const DayNavigationBar(),
                Expanded(
                  child: _DayBody(
                    onEntryTap: (entry) => showEntrySheet(context, entry),
                    onPreviousDay: () =>
                        ref.read(selectedDayProvider.notifier).previousDay(),
                    onNextDay: () =>
                        ref.read(selectedDayProvider.notifier).nextDay(),
                  ),
                ),
                const _DayTotalsFooter(),
              ],
            ),
          ),
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

/// The day itself. Horizontal swipe changes day; the arrows and date picker in
/// [DayNavigationBar] do the same without a gesture (SPEC §10.1).
class _DayBody extends ConsumerWidget {
  const _DayBody({
    required this.onEntryTap,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final void Function(TimeEntry entry) onEntryTap;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(dayTimelineProvider);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 200) {
          onPreviousDay();
        } else if (velocity < -200) {
          onNextDay();
        }
      },
      // A day with no entries is one big hatched gap, which tells the user
      // nothing. Say so in words instead.
      child: timeline.isEmpty
          ? const _EmptyDay()
          : DayCalendar(onEntryTap: onEntryTap),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('No entries for this day'),
          const SizedBox(height: 8),
          Text(
            'Tap Start to track something.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) {
    // Also to the console, so a failure is diagnosable from a log rather than
    // only from the screen.
    debugPrint('time-log: the database could not be opened: $error');
    return Center(
      // Scrollable and bounded: a database error can carry a very long message,
      // and an error screen that overflows is no help to anyone.
      child: SingleChildScrollView(
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
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
