import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/adaptive.dart';
import '../../app/design.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../domain/export/csv_export.dart';
import '../today/action_feedback.dart';
import '../today/today_providers.dart';
import 'export_providers.dart';

/// Export the entries for a date range (SPEC §8.6).
Future<void> showExportSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ExportSheet(),
    );

/// The ranges worth one tap. Anything else is [ExportPreset.custom].
enum ExportPreset {
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  custom('Custom…');

  const ExportPreset(this.label);

  final String label;
}

class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key});

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  ExportPreset _preset = ExportPreset.thisWeek;

  /// Local dates, inclusive at both ends. Set by a preset or by the picker.
  ({DateTime first, DateTime last})? _custom;

  bool _sending = false;

  /// The local days the chosen preset covers, inclusive.
  ({DateTime first, DateTime last}) _days(BuildContext context) {
    if (_preset == ExportPreset.custom && _custom != null) return _custom!;

    final today = _dateOnly(ref.read(appClockProvider).nowUtc().toLocal());
    final weekStart = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    // How far back the current week began. `weekday` is 1..7 with Monday first;
    // firstDayOfWeekIndex is 0..6 with Sunday first.
    final daysIntoWeek = (today.weekday - weekStart) % 7;

    return switch (_preset) {
      ExportPreset.thisWeek => (
        first: today.subtract(Duration(days: daysIntoWeek)),
        last: today,
      ),
      ExportPreset.lastWeek => (
        first: today.subtract(Duration(days: daysIntoWeek + 7)),
        last: today.subtract(Duration(days: daysIntoWeek + 1)),
      ),
      ExportPreset.thisMonth => (
        first: DateTime(today.year, today.month),
        last: today,
      ),
      ExportPreset.lastMonth => (
        first: DateTime(today.year, today.month - 1),
        last: DateTime(today.year, today.month, 0),
      ),
      // Only before a custom range has been picked; the preset keeps its own
      // dates once it has them.
      ExportPreset.custom => (first: today, last: today),
    };
  }

  static DateTime _dateOnly(DateTime local) =>
      DateTime(local.year, local.month, local.day);

  /// Local dates to instants, through the day windows — so a range containing
  /// a DST change is 23 or 25 hours longer than a naive multiplication would
  /// make it (SPEC §5.3).
  ExportRange _range(BuildContext context) {
    final days = _days(context);
    final calculator = ref.read(dayWindowsProvider);
    return (
      from: calculator
          .forDate(days.first.year, days.first.month, days.first.day)
          .startUtc,
      to: calculator
          .forDate(days.last.year, days.last.month, days.last.day)
          .endUtc,
    );
  }

  Future<void> _pickCustom() async {
    final days = _days(context);
    final picked = await showAdaptiveDateRangePicker(
      context,
      firstDay: days.first,
      lastDay: days.last,
      earliest: DateTime(2000),
      latest: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = ExportPreset.custom;
      _custom = picked;
    });
  }

  Future<void> _export(CsvExport csv) async {
    if (_sending) return;
    setState(() => _sending = true);
    final days = _days(context);
    try {
      await ref
          .read(exportDeliveryProvider)
          .send(
            fileName: csvFileName(firstDay: days.first, lastDay: days.last),
            text: csv.text,
            mimeType: 'text/csv',
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showUndoableFeedback(
        context,
        message: 'Exported ${csv.rowCount} entries',
        undo: null,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _days(context);
    final export = ref.watch(rangeExportProvider(_range(context)));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Export entries',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Insets.lg),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                for (final preset in ExportPreset.values)
                  ChoiceChip(
                    label: Text(preset.label),
                    selected: _preset == preset,
                    onSelected: (_) {
                      if (preset == ExportPreset.custom) {
                        _pickCustom();
                      } else {
                        setState(() => _preset = preset);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            _Summary(days: days, export: export),
            const SizedBox(height: Insets.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: switch (export) {
                  AsyncData(:final value) when !value.isEmpty && !_sending =>
                    () => _export(value),
                  _ => null,
                },
                child: const Text('Export CSV'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What you are about to get: the range, how many entries, how long.
class _Summary extends StatelessWidget {
  const _Summary({required this.days, required this.export});

  final ({DateTime first, DateTime last}) days;
  final AsyncValue<CsvExport> export;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final format = DateFormat.yMMMd();
    final range = days.first == days.last
        ? format.format(days.first)
        : '${format.format(days.first)} – ${format.format(days.last)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(range, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Insets.xs),
          Text(
            switch (export) {
              AsyncData(:final value) when value.isEmpty =>
                'Nothing tracked in this range',
              AsyncData(:final value) =>
                '${value.rowCount} ${value.rowCount == 1 ? 'entry' : 'entries'}'
                    ' · ${formatDuration(value.total)}',
              AsyncError() => 'Could not read the entries',
              _ => 'Counting…',
            },
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
