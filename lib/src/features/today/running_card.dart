import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import 'today_providers.dart';

/// The pinned card at the top of Today (SPEC §8.1): what is running, for how
/// long, and one tap to stop it.
class RunningCard extends ConsumerWidget {
  const RunningCard({
    required this.onStop,
    required this.onResumeLast,
    required this.onFixStart,
    super.key,
  });

  final VoidCallback onStop;
  final VoidCallback onResumeLast;
  final VoidCallback onFixStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(runningEntryProvider).value;
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();

    if (running == null) {
      return _IdleCard(onResumeLast: onResumeLast);
    }

    final activity = activities[running.activityId];
    final now = ref.watch(appClockProvider).nowUtc();
    if (running.startUtc.isAfter(now)) {
      return _FutureStartCard(onFixStart: onFixStart);
    }

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          // Coarse, on-demand label. The ticking readout below is excluded from
          // semantics on purpose: a per-second live region would make the screen
          // unusable with a screen reader (SPEC §10.4).
          label:
              'Running: ${activity?.name ?? 'Activity'}, started '
              '${formatTimeOfDay(running.startUtc.toLocal(), use24h: settings.use24HourClock)}, '
              '${formatDurationVerbose(running.durationAt(now))} so far',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const _RunningDot(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activity?.name ?? 'Activity',
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (running.note != null && running.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          running.note!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'since ${formatTimeOfDay(running.startUtc.toLocal(), use24h: settings.use24HourClock)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    ExcludeSemantics(child: _ElapsedText(entry: running)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rebuilt once a second, and nothing else is (SPEC §11.4).
class _ElapsedText extends ConsumerWidget {
  const _ElapsedText({required this.entry});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now =
        ref.watch(secondTickerProvider).value ??
        ref.watch(appClockProvider).nowUtc();
    // A numeric readout must never wrap: at large text scales "1:12:00" would
    // otherwise break across five lines. Scaling it down to fit keeps it as big
    // as the space allows, and the duration is also carried in words by the
    // card's semantics label, so nothing is lost (SPEC §10.2, §10.4).
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatElapsed(entry.durationAt(now)),
          maxLines: 1,
          softWrap: false,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _RunningDot extends StatelessWidget {
  const _RunningDot();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    // Colour alone never carries meaning (SPEC §10.3), so this sits next to the
    // activity name and the "Running" semantics label, not instead of them.
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _IdleCard extends ConsumerWidget {
  const _IdleCard({required this.onResumeLast});

  final VoidCallback onResumeLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastFinishedEntryProvider).value;
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final lastName = last == null ? null : activities[last.activityId]?.name;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            const Expanded(child: Text('Nothing is running')),
            if (lastName != null)
              TextButton.icon(
                onPressed: onResumeLast,
                icon: const Icon(Icons.play_arrow),
                label: Text('Resume $lastName'),
              ),
          ],
        ),
      ),
    );
  }
}

/// SPEC §9.2: a backwards clock jump shows an explanation and a fix, never a
/// negative duration.
class _FutureStartCard extends StatelessWidget {
  const _FutureStartCard({required this.onFixStart});

  final VoidCallback onFixStart;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('This entry started in the future'),
          const SizedBox(height: 4),
          Text(
            'The device clock may have changed.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onFixStart,
            child: const Text('Fix start time'),
          ),
        ],
      ),
    ),
  );
}
