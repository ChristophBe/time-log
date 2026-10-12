import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/adaptive.dart';
import '../../app/design.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/timeline_writer.dart';
import 'action_feedback.dart';
import 'today_providers.dart';

/// "Still tracking *X* after 8 h?" (SPEC §8.1).
///
/// A banner, never a modal and never a notification you cannot dismiss: the
/// app has no idea whether you forgot to stop or genuinely worked all day, and
/// only one of those is a mistake. Dismissing it is **Keep going**, and it
/// stays dismissed for that run rather than coming back a minute later.
///
/// Measured over the whole run via [runStartUtcProvider], not over the current
/// entry: SPEC §6.11 cuts the running entry at midnight, so an overnight clock
/// -- the one case this banner exists for -- would otherwise be the one case it
/// never asked about.
class LongRunBanner extends ConsumerStatefulWidget {
  const LongRunBanner({super.key});

  @override
  ConsumerState<LongRunBanner> createState() => _LongRunBannerState();
}

class _LongRunBannerState extends ConsumerState<LongRunBanner> {
  /// Keyed on when the run began rather than on the entry id, so the midnight
  /// cut handing us a new entry does not un-dismiss the banner (SPEC §6.11).
  DateTime? _dismissedRunStart;

  Future<void> _stopAt(DateTime startUtc, String entryId, bool use24h) async {
    final now = ref.read(appClockProvider).nowUtc();
    final picked = await showAdaptiveTimePicker(
      context,
      initial: TimeOfDay.fromDateTime(now.toLocal()),
      helpText: 'Stop at',
      use24h: use24h,
    );
    if (picked == null || !mounted) return;

    final local = now.toLocal();
    final end = DateTime(
      local.year,
      local.month,
      local.day,
      picked.hour,
      picked.minute,
    ).toUtc();

    final undo = await ref
        .read(timelineWriterProvider)
        .setEntryTimes(entryId: entryId, startUtc: startUtc, endUtc: end);
    if (!mounted) return;
    showUndoableFeedback(context, message: 'Stopped', undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(runningEntryProvider).value;
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    if (running == null || settings.longRun <= Duration.zero) {
      return const SizedBox.shrink();
    }

    // Coarse on purpose: this is watched by the 30-second tick, not the
    // per-second one. A banner does not need to arrive on the second.
    final now =
        ref.watch(coarseTickerProvider).value ??
        ref.watch(appClockProvider).nowUtc();
    // Nothing at all until the run's real start is known, rather than falling
    // back to this entry's own start for a frame: a question that waits one
    // frame costs nothing, whereas asking it on a guess means **Keep going**
    // can record the guess and let the banner back in a frame later.
    final runStart = ref.watch(runStartUtcProvider).value;
    if (runStart == null) return const SizedBox.shrink();

    final elapsed = now.difference(runStart);
    final dismissed = _dismissedRunStart?.isAtSameMomentAs(runStart) ?? false;
    if (elapsed < settings.longRun || dismissed) {
      return const SizedBox.shrink();
    }

    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final name = activities[running.activityId]?.name ?? 'this';
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: Radii.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Still tracking $name after ${formatDuration(elapsed)}?',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () => _stopAt(
                  running.startUtc,
                  running.id,
                  settings.use24HourClock,
                ),
                child: const Text('Stop at…'),
              ),
              const SizedBox(width: Insets.sm),
              TextButton(
                onPressed: () => setState(() => _dismissedRunStart = runStart),
                child: const Text('Keep going'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
