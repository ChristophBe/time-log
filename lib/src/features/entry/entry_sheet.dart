import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../today/resume_action.dart';
import '../today/today_providers.dart';

/// Details of one entry (SPEC §8.4). P3 adds the editable time fields.
Future<void> showEntrySheet(BuildContext context, TimeEntry entry) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntrySheet(entry: entry),
    );

class EntrySheet extends ConsumerWidget {
  const EntrySheet({required this.entry, super.key});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final activity = activities[entry.activityId];
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final now = ref.watch(appClockProvider).nowUtc();
    final colors = ActivityPalette.forSeed(
      activity?.colorSeed ?? 0,
      Theme.of(context).brightness,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colors.fill,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
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
            if (entry.note != null && entry.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(entry.note!),
              ),
            const SizedBox(height: 16),
            _ReadOnlyRow(
              label: 'Start',
              value: formatTimeOfDay(
                entry.startUtc.toLocal(),
                use24h: settings.use24HourClock,
              ),
            ),
            _ReadOnlyRow(
              label: 'End',
              value: entry.endUtc == null
                  ? 'running'
                  : formatTimeOfDay(
                      entry.endUtc!.toLocal(),
                      use24h: settings.use24HourClock,
                    ),
            ),
            _ReadOnlyRow(
              label: 'Duration',
              value: formatDurationCompact(entry.durationAt(now)),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: entry.isRunning
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await resumeOrContinue(context, ref, entry);
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: <Widget>[
        SizedBox(width: 96, child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
