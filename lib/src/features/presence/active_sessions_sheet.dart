import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/presence/active_session.dart';
import '../../domain/presence/unlogged_active.dart';
import '../../domain/timeline/clipping.dart';
import '../../domain/timeline/invariants.dart';
import '../../domain/timeline_writer.dart';
import '../calendar/fill_gap_sheet.dart';
import '../today/action_feedback.dart';
import '../today/today_providers.dart';
import 'presence_providers.dart';

/// The day's unlogged active time, each span one tap from being an entry
/// (SPEC §9.9).
Future<void> showActiveSessionsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ActiveSessionsSheet(),
    );

class _ActiveSessionsSheet extends ConsumerWidget {
  const _ActiveSessionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(selectedDayProvider);
    final use24h = (ref.watch(appSettingsProvider).value ?? const AppSettings())
        .use24HourClock;
    final spans = unloggedActive(
      sessions: ref.watch(daySessionsProvider).value ?? const <ActiveSession>[],
      entries: ref.watch(dayEntriesProvider).value ?? const [],
      from: window.startUtc,
      to: window.endUtc,
      now: ref.watch(appClockProvider).nowUtc(),
    );
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Text('Unlogged active time', style: textTheme.titleLarge),
            ),
            const SizedBox(height: Insets.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Text(
                spans.isEmpty
                    ? 'Every active minute of this day is already logged.'
                    : 'Time you were at the computer that no entry covers. '
                          'Pick a span to log it.',
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: Insets.sm),
            for (final span in spans)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                ),
                title: Text(
                  '${_time(span.start, use24h)} – ${_time(span.end, use24h)}',
                  style: AppType.numeric(textTheme.bodyLarge),
                ),
                trailing: Text(
                  formatDuration(span.end.difference(span.start)),
                  style: AppType.numeric(textTheme.bodyMedium),
                ),
                onTap: () => _log(context, ref, span, use24h: use24h),
              ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime instant, bool use24h) =>
      formatTimeOfDay(instant.toLocal(), use24h: use24h);

  /// Asked about in its own sheet and written through the one writer, like any
  /// other entry added after the fact. The list stays open behind it, so a day
  /// of several spans does not have to be reopened for each one.
  Future<void> _log(
    BuildContext context,
    WidgetRef ref,
    ClippedSpan span, {
    required bool use24h,
  }) async {
    final name = await showFillGapSheet(
      context,
      startLocal: span.start.toLocal(),
      endLocal: span.end.toLocal(),
      duration: span.end.difference(span.start),
      use24h: use24h,
      title: 'Log this time',
    );
    if (name == null || !context.mounted) return;
    try {
      final undo = await ref
          .read(timelineWriterProvider)
          .insertEntry(name: name, startUtc: span.start, endUtc: span.end);
      if (!context.mounted) return;
      showUndoableFeedback(context, message: 'Added $name', undo: undo);
    } on InvariantViolation catch (violation) {
      if (!context.mounted) return;
      showUndoableFeedback(context, message: violation.detail, undo: null);
    }
  }
}
