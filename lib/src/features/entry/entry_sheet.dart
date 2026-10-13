import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/adaptive.dart';
import '../../app/design.dart';
import '../../app/glass.dart';
import '../../app/platform_style.dart';
import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/invariants.dart';
import '../../domain/timeline/time_conflicts.dart';
import '../../domain/timeline_writer.dart';
import '../today/action_feedback.dart';
import '../today/resume_action.dart';
import '../today/today_providers.dart';
import 'activity_picker.dart';
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
  late final TextEditingController _note = TextEditingController(
    text: widget.entry.note ?? '',
  );
  final FocusNode _noteFocus = FocusNode(debugLabel: 'entry note');

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _commitNote();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

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

  Future<void> _pickTime({required bool isStart, required bool use24h}) async {
    final current = (isStart ? _start : _end)!.toLocal();
    // A dial on Material, a wheel on Apple; the same TimeOfDay either way, so
    // §7's clamping never learns which one was used.
    final picked = await showAdaptiveTimePicker(
      context,
      initial: TimeOfDay.fromDateTime(current),
      helpText: isStart ? 'Start time' : 'End time',
      use24h: use24h,
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

  /// The note commits on its own rather than through Save, so one Save never
  /// produces two undo steps (SPEC §7.5). It is a different kind of edit from
  /// the three time fields: nothing on the timeline moves.
  Future<void> _commitNote() async {
    final typed = _note.text.trim();
    final current = widget.entry.note ?? '';
    if (typed == current) return;
    final writer = ref.read(timelineWriterProvider);
    final undo = await writer.setEntryNote(
      entryId: widget.entry.id,
      note: typed,
    );
    if (!mounted) return;
    showUndoableFeedback(context, message: 'Note changed', undo: undo);
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

  /// SPEC §6.10: relabel this one span, leaving its times and note alone.
  ///
  /// The sheet closes once the entry has moved, because its header is built
  /// from the entry it was handed and would keep showing the old name and the
  /// old spine colour. Every other committing action here closes it too; the
  /// note is the exception, and the note keeps its text in a controller.
  Future<void> _changeActivity(Activity activity) async {
    final changed = await showActivityPicker(
      context,
      entry: widget.entry,
      current: activity,
    );
    if (changed && mounted) Navigator.of(context).pop();
  }

  /// SPEC §6.6: split at a chosen instant, not at a fixed one.
  ///
  /// The midpoint is only the picker's starting value — "retro-label the second
  /// half" almost never means "exactly halfway", and the writer has always
  /// taken an arbitrary instant.
  Future<void> _split({required bool use24h}) async {
    final end = _end;
    if (end == null) return;
    final midpoint = _start.add(end.difference(_start) ~/ 2);
    final picked = await showAdaptiveTimePicker(
      context,
      initial: TimeOfDay.fromDateTime(midpoint.toLocal()),
      helpText: 'Split at',
      use24h: use24h,
    );
    if (picked == null || !mounted) return;

    final local = midpoint.toLocal();
    final at = DateTime(
      local.year,
      local.month,
      local.day,
      picked.hour,
      picked.minute,
    ).toUtc();

    final writer = ref.read(timelineWriterProvider);
    try {
      final undo = await writer.split(entryId: widget.entry.id, atUtc: at);
      if (!mounted) return;
      Navigator.of(context).pop();
      showUndoableFeedback(context, message: 'Entry split', undo: undo);
    } on InvariantViolation catch (error) {
      if (!mounted) return;
      showUndoableFeedback(context, message: error.detail, undo: null);
    }
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

    return GlassSurface(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PlatformStyle.from(context).sheetRadius),
      ),
      edge: GlassEdge.top,
      opacity: 0.88,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            0,
            Insets.lg,
            Insets.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // The same spine the entry's block carries on the calendar, so
                  // the sheet is visibly about *that* block.
                  Container(
                    width: Strokes.spine,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.edge,
                      borderRadius: Radii.pill,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    // Tap to relabel this entry, or -- a step further in --
                    // to rename the activity itself (SPEC §8.4, §6.10, §6.7).
                    child: InkWell(
                      onTap: activity == null
                          ? null
                          : () => _changeActivity(activity),
                      borderRadius: Radii.smAll,
                      child: Semantics(
                        button: activity != null,
                        hint: activity == null
                            ? null
                            : 'Double tap to change, rename or recolour',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Insets.md,
                          ),
                          child: Text(
                            activity?.name ?? 'Activity',
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isRunning)
                    const Chip(
                      label: Text('Running'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: Insets.md),
              TextField(
                key: const Key('entry-sheet-note'),
                controller: _note,
                focusNode: _noteFocus,
                maxLength: TimeEntry.maxNoteLength,
                minLines: 1,
                maxLines: 3,
                // Enter inserts a line rather than committing: a note is prose
                // and may want more than one line. It commits when the field
                // lets go instead.
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'What makes this span different',
                  counterText: '',
                ),
              ),
              const SizedBox(height: Insets.lg),
              // One group, not three loose rows: Start, End and Duration are
              // three views of the same two instants, and editing any two moves
              // the third (SPEC §8.4).
              _FieldGroup(
                children: <Widget>[
                  _TimeField(
                    label: 'Start',
                    value: formatTimeOfDay(_start.toLocal(), use24h: use24h),
                    step: step,
                    onPick: () => _pickTime(isStart: true, use24h: use24h),
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
                      onPick: () => _pickTime(isStart: false, use24h: use24h),
                      onEarlier: () => _moveEnd(-step),
                      onLater: () => _moveEnd(step),
                    ),
                  if (_isRunning)
                    _StaticField(
                      label: 'Duration',
                      value: formatDuration(_durationAt(now)),
                    )
                  else
                    _TimeField(
                      label: 'Duration',
                      value: formatDuration(_durationAt(now)),
                      step: step,
                      onEarlier: () => _changeDuration(-step),
                      onLater: () => _changeDuration(step),
                    ),
                ],
              ),
              if (conflict != null)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.md),
                  child: _ConflictNotice(
                    message: describeConflict(
                      conflict,
                      use24h: use24h,
                      previousName: neighbours?.previous == null
                          ? null
                          : activities[neighbours!.previous!.activityId]?.name,
                      nextName: neighbours?.next == null
                          ? null
                          : activities[neighbours!.next!.activityId]?.name,
                    ),
                  ),
                ),
              const SizedBox(height: Insets.lg),
              // Secondary actions first and smaller, the primary one last and
              // full width at the thumb end of the sheet.
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (!_isRunning)
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await resumeOrContinue(context, ref, widget.entry);
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Resume'),
                    ),
                  if (!_isRunning)
                    OutlinedButton(
                      onPressed: () => _split(use24h: use24h),
                      child: const Text('Split here…'),
                    ),
                  TextButton.icon(
                    onPressed: _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _changed && conflict == null
                      ? () => _save(conflict)
                      : null,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three time fields, in one container with hairlines between them.
class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hairline = AppColors.from(context).hairline;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: Strokes.hairline,
                thickness: Strokes.hairline,
                color: hairline,
                indent: Insets.md,
                endIndent: Insets.md,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A typed value that breaks a clamp, said in place rather than on commit
/// (SPEC §7.2).
class _ConflictNotice extends StatelessWidget {
  const _ConflictNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: Radii.smAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              key: const Key('entry-sheet-conflict'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// A time or duration with a picker and two steppers.
///
/// The steppers are the keyboard- and screen-reader-reachable equivalent of
/// dragging the boundary on the calendar (SPEC §10.1), so they are a permanent
/// part of the row rather than something revealed on hover.
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.xs,
        Insets.xs,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: Metrics.fieldLabel,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: onPick == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                      ),
                      child: Text(
                        value,
                        style: AppType.numeric(
                          Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: onPick,
                      style: TextButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest,
                        foregroundColor: scheme.onSurface,
                        textStyle: AppType.numeric(
                          Theme.of(context).textTheme.titleMedium,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.md,
                        ),
                      ),
                      child: Text(value),
                    ),
            ),
          ),
          _Stepper(
            icon: Icons.remove_rounded,
            tooltip: '$label $minutes minutes earlier',
            onPressed: onEarlier,
          ),
          _Stepper(
            icon: Icons.add_rounded,
            tooltip: '$label $minutes minutes later',
            onPressed: onLater,
          ),
        ],
      ),
    );
  }
}

/// The label column of a field row.
///
/// Its width follows the text scale: a fixed 88 is right at 100% and clips
/// "Duration" at 200%, and a row whose label wraps while its value does not
/// stops looking like a row (SPEC §10.2).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.textScalerOf(context)
        .scale(Metrics.fieldLabel)
        .clamp(Metrics.fieldLabel, 180.0),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
  );
}

class _StaticField extends StatelessWidget {
  const _StaticField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Insets.md,
      vertical: Insets.md,
    ),
    child: Row(
      children: <Widget>[
        _FieldLabel(label),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(
            value,
            style: AppType.numeric(Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ],
    ),
  );
}
