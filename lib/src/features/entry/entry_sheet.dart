import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/time_conflicts.dart';
import '../../domain/timeline_writer.dart';
import '../today/action_feedback.dart';
import '../today/resume_action.dart';
import '../today/today_providers.dart';
import 'conflict_text.dart';
import 'entry_providers.dart';

/// Details and times of one entry (SPEC §8.4).
///
/// This is the non-gesture path to everything the calendar offers by drag: the
/// three time fields and their steppers do exactly what dragging a boundary
/// does, which is what makes the editing accessible (SPEC §10.1).
Future<void> showEntrySheet(BuildContext context, TimeEntry entry) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntrySheet(entry: entry),
    );

class EntrySheet extends ConsumerStatefulWidget {
  const EntrySheet({required this.entry, super.key});

  final TimeEntry entry;

  @override
  ConsumerState<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<EntrySheet> {
  late DateTime _start = widget.entry.startUtc;
  late DateTime? _end = widget.entry.endUtc;

  bool get _isRunning => widget.entry.isRunning;

  bool get _changed =>
      _start != widget.entry.startUtc || _end != widget.entry.endUtc;

  Duration _durationAt(DateTime now) =>
      (_end ?? now).difference(_start).isNegative
      ? Duration.zero
      : (_end ?? now).difference(_start);

  /// One step of the steppers. A snap of "off" still steps by a minute, since a
  /// zero-minute step would do nothing.
  Duration _step(AppSettings settings) => settings.snap > Duration.zero
      ? settings.snap
      : const Duration(minutes: 1);

  void _moveStart(Duration by) => setState(() => _start = _start.add(by));

  void _moveEnd(Duration by) {
    if (_end == null) return;
    setState(() => _end = _end!.add(by));
  }

  /// Editing the duration moves the end and leaves the start where it is, so the
  /// three fields always agree (SPEC §8.4).
  void _changeDuration(Duration by) {
    if (_end == null) return;
    setState(() => _end = _end!.add(by));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = (isStart ? _start : _end)!.toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: isStart ? 'Start time' : 'End time',
    );
    if (picked == null) return;
    final updated = DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    ).toUtc();
    setState(() {
      if (isStart) {
        _start = updated;
      } else {
        _end = updated;
      }
    });
  }

  Future<void> _save(TimeConflict? conflict) async {
    if (conflict != null) return;
    final writer = ref.read(timelineWriterProvider);
    final undo = await writer.setEntryTimes(
      entryId: widget.entry.id,
      startUtc: _start,
      endUtc: _end,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    showUndoableFeedback(context, message: 'Times changed', undo: undo);
  }

  Future<void> _delete() async {
    final writer = ref.read(timelineWriterProvider);
    final undo = await writer.delete(widget.entry.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showUndoableFeedback(context, message: 'Entry deleted', undo: undo);
  }

  Future<void> _split() async {
    final end = _end;
    if (end == null) return;
    final midpoint = _start.add(end.difference(_start) ~/ 2);
    final writer = ref.read(timelineWriterProvider);
    final undo = await writer.split(entryId: widget.entry.id, atUtc: midpoint);
    if (!mounted) return;
    Navigator.of(context).pop();
    showUndoableFeedback(context, message: 'Entry split', undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final activity = activities[widget.entry.activityId];
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final now = ref.watch(appClockProvider).nowUtc();
    final neighbours = ref
        .watch(entryNeighboursProvider(widget.entry.id))
        .value;
    final step = _step(settings);
    final use24h = settings.use24HourClock;

    final conflict = findTimeConflict(
      original: widget.entry,
      startUtc: _start,
      endUtc: _end,
      previous: neighbours?.previous,
      next: neighbours?.next,
      now: now,
    );

    final colors = ActivityPalette.forSeed(
      activity?.colorSeed ?? 0,
      Theme.of(context).brightness,
    );

    return SafeArea(
      child: SingleChildScrollView(
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
                if (_isRunning)
                  Chip(
                    label: const Text('Running'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (widget.entry.note != null && widget.entry.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.entry.note!),
              ),
            const SizedBox(height: 8),
            _TimeField(
              label: 'Start',
              value: formatTimeOfDay(_start.toLocal(), use24h: use24h),
              step: step,
              onPick: () => _pickTime(isStart: true),
              onEarlier: () => _moveStart(-step),
              onLater: () => _moveStart(step),
            ),
            if (_isRunning)
              const _StaticField(label: 'End', value: 'running')
            else
              _TimeField(
                label: 'End',
                value: formatTimeOfDay(_end!.toLocal(), use24h: use24h),
                step: step,
                onPick: () => _pickTime(isStart: false),
                onEarlier: () => _moveEnd(-step),
                onLater: () => _moveEnd(step),
              ),
            if (_isRunning)
              _StaticField(
                label: 'Duration',
                value: formatDurationCompact(_durationAt(now)),
              )
            else
              _TimeField(
                label: 'Duration',
                value: formatDurationCompact(_durationAt(now)),
                step: step,
                onEarlier: () => _changeDuration(-step),
                onLater: () => _changeDuration(step),
              ),
            if (conflict != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  describeConflict(
                    conflict,
                    use24h: use24h,
                    previousName: neighbours?.previous == null
                        ? null
                        : activities[neighbours!.previous!.activityId]?.name,
                    nextName: neighbours?.next == null
                        ? null
                        : activities[neighbours!.next!.activityId]?.name,
                  ),
                  key: const Key('entry-sheet-conflict'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: _changed && conflict == null
                      ? () => _save(conflict)
                      : null,
                  child: const Text('Save'),
                ),
                if (!_isRunning)
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await resumeOrContinue(context, ref, widget.entry);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                if (!_isRunning)
                  OutlinedButton(
                    onPressed: _split,
                    child: const Text('Split in half'),
                  ),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A time or duration with a picker and two steppers.
///
/// The steppers are the keyboard- and screen-reader-reachable equivalent of
/// dragging the boundary on the calendar (SPEC §10.1).
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.step,
    required this.onEarlier,
    required this.onLater,
    this.onPick,
  });

  final String label;
  final String value;
  final Duration step;
  final VoidCallback onEarlier;
  final VoidCallback onLater;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final minutes = step.inMinutes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 88, child: Text(label)),
          Expanded(
            child: onPick == null
                ? Text(value, style: Theme.of(context).textTheme.titleMedium)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: onPick,
                      child: Text(value),
                    ),
                  ),
          ),
          IconButton(
            onPressed: onEarlier,
            icon: const Icon(Icons.remove),
            tooltip: '$label $minutes minutes earlier',
          ),
          IconButton(
            onPressed: onLater,
            icon: const Icon(Icons.add),
            tooltip: '$label $minutes minutes later',
          ),
        ],
      ),
    );
  }
}

class _StaticField extends StatelessWidget {
  const _StaticField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: <Widget>[
        SizedBox(width: 88, child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
