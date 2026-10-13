import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/palette.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import 'today_providers.dart';

/// The second row of the day header (SPEC §8.1): what is running, for how long,
/// and one tap to stop it.
///
/// A band rather than a card. It is one of three states -- running, idle,
/// started-in-the-future -- and all three are drawn in the same shell at the
/// same height, so the header does not resize underneath your finger the
/// instant you start or stop something. The card it replaced changed height by
/// about sixty pixels between those states.
///
/// When something is running the band takes that activity's own tint and edge,
/// which is the same colour its block carries on the calendar below: one
/// activity, one colour, wherever it appears.
class RunningBand extends ConsumerWidget {
  const RunningBand({
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

    if (running == null) return _IdleBand(onResumeLast: onResumeLast);

    final activity = activities[running.activityId];
    final now = ref.watch(appClockProvider).nowUtc();
    if (running.startUtc.isAfter(now)) {
      return _FutureStartBand(onFixStart: onFixStart);
    }

    final colors = ActivityPalette.forSeed(
      activity?.colorSeed ?? 0,
      Theme.of(context).brightness,
    );
    final since = formatTimeOfDay(
      running.startUtc.toLocal(),
      use24h: settings.use24HourClock,
    );

    // At large text sizes a single row leaves every part of it with too little
    // room, and the name, the start time and the note all ellipsize to two
    // characters each. Past that point the band stacks instead and grows
    // taller, which is the one dimension there is room in (SPEC §10.2).
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;

    return BandShell(
      background: colors.tint,
      spine: colors.edge,
      child: Semantics(
        container: true,
        // Coarse, on-demand label. The ticking readout below is excluded from
        // semantics on purpose: a per-second live region would make the screen
        // unusable with a screen reader (SPEC §10.4).
        label:
            'Running: ${activity?.name ?? 'Activity'}, started $since, '
            '${formatDurationVerbose(running.durationAt(now))} so far',
        child: _BandLayout(
          stacked: stacked,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                activity?.name ?? 'Activity',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Two Texts rather than one interpolated string: the note
                // is the part that may be long, so it is the part that
                // ellipsizes.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: Text('since $since')),
                    if (running.note != null &&
                        running.note!.isNotEmpty) ...<Widget>[
                      const Text(' · '),
                      Flexible(child: Text(running.note!)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          elapsed: ExcludeSemantics(
            child: _ElapsedText(entry: running, alignLeft: stacked),
          ),
          // No icon: "Stop" is one short word, and the band's horizontal room
          // is better spent on the activity's name and start time than on a
          // glyph that repeats it.
          action: FilledButton.tonal(
            onPressed: onStop,
            child: const Text('Stop'),
          ),
        ),
      ),
    );
  }
}

/// The running band's three parts, side by side or stacked.
class _BandLayout extends StatelessWidget {
  const _BandLayout({
    required this.stacked,
    required this.title,
    required this.elapsed,
    required this.action,
  });

  final bool stacked;
  final Widget title;
  final Widget elapsed;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    if (!stacked) {
      // Both halves are tight, so there is no slack left over to pool at the
      // end of the row: the readout and Stop sit against the band's right
      // edge, where the eye goes for the number and the thumb for the button.
      // A loose Flexible around the readout looked right only until the
      // string was short, and then left a hole after Stop.
      return Row(
        children: <Widget>[
          Expanded(flex: 3, child: title),
          const SizedBox(width: Insets.sm),
          Expanded(flex: 2, child: elapsed),
          const SizedBox(width: Insets.sm),
          action,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        title,
        const SizedBox(height: Insets.sm),
        Row(
          children: <Widget>[
            Expanded(child: elapsed),
            const SizedBox(width: Insets.sm),
            action,
          ],
        ),
      ],
    );
  }
}

/// The shell all three band states share: same height, same padding, same place
/// for the activity's colour.
class BandShell extends StatelessWidget {
  const BandShell({
    required this.child,
    this.background,
    this.spine,
    super.key,
  });

  final Widget child;
  final Color? background;
  final Color? spine;

  @override
  Widget build(BuildContext context) {
    // Scaled rather than fixed: at 200% text the same content genuinely needs
    // twice the room, and a hard 64 would clip it (SPEC §10.2). It stays a
    // *minimum*, so the three states still agree on height at any one scale.
    final minHeight = MediaQuery.textScalerOf(context)
        .scale(Metrics.runningBand);

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      margin: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      decoration: BoxDecoration(
        color: background ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: Radii.smAll,
        border: Border(
          left: BorderSide(
            color: spine ?? Colors.transparent,
            width: Strokes.spine,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: child,
    );
  }
}

/// Rebuilt once a second, and nothing else is (SPEC §11.4).
class _ElapsedText extends ConsumerWidget {
  const _ElapsedText({required this.entry, this.alignLeft = false});

  final TimeEntry entry;
  final bool alignLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now =
        ref.watch(secondTickerProvider).value ??
        ref.watch(appClockProvider).nowUtc();
    // A numeric readout must never wrap: at large text scales "1:12:00" would
    // otherwise break across five lines. Scaling it down to fit keeps it as big
    // as the space allows, and the duration is also carried in words by the
    // band's semantics label, so nothing is lost (SPEC §10.2, §10.4).
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Text(
        formatElapsed(entry.durationAt(now)),
        maxLines: 1,
        softWrap: false,
        style: AppType.numeric(Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class _IdleBand extends ConsumerWidget {
  const _IdleBand({required this.onResumeLast});

  final VoidCallback onResumeLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastFinishedEntryProvider).value;
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final lastName = last == null ? null : activities[last.activityId]?.name;

    return BandShell(
      background: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Nothing is running',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lastName != null)
            // Tight, and right-aligned inside its half: the action belongs at
            // the band's trailing edge, where Stop is in the running state.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onResumeLast,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    'Resume $lastName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// SPEC §9.2: a backwards clock jump shows an explanation and a fix, never a
/// negative duration.
class _FutureStartBand extends StatelessWidget {
  const _FutureStartBand({required this.onFixStart});

  final VoidCallback onFixStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BandShell(
      background: scheme.errorContainer,
      spine: scheme.error,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'This entry started in the future',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: scheme.onErrorContainer),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'The device clock may have changed.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          FilledButton.tonal(
            onPressed: onFixStart,
            child: const Text('Fix start time'),
          ),
        ],
      ),
    );
  }
}
