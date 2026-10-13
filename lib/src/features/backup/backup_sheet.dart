import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../core/clock.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/backup/json_backup.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/timeline_writer.dart';
import '../export/export_providers.dart';
import '../today/action_feedback.dart';
import 'backup_providers.dart';

/// Everything the app holds, as one file (SPEC §8.6).
///
/// Separate from the CSV range export, and the difference is the point: that
/// one is an extract for a human, this one is a backup that has to come back in
/// unchanged (§14.10).
Future<void> exportEverything(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(timeEntryRepositoryProvider);
  final data = await repository.readForBackup();
  final settings = ref.read(appSettingsProvider).value ?? const AppSettings();
  final now = ref.read(appClockProvider).nowUtc();
  final text = encodeBackup(
    activities: data.activities,
    entries: data.entries,
    settings: settings,
    exportedAt: now,
  );
  final stamp = now.toIso8601String().split('T').first;
  await ref
      .read(exportDeliveryProvider)
      .send(
        fileName: 'time-log-backup-$stamp.json',
        text: text,
        mimeType: 'application/json',
      );
  if (!context.mounted) return;
  showUndoableFeedback(
    context,
    message: 'Exported ${data.entries.length} entries',
    undo: null,
  );
}

/// Pick a file, work out what it would do, and show that before doing it.
Future<void> startImport(BuildContext context, WidgetRef ref) async {
  final text = await ref.read(backupSourceProvider).pickBackup();
  if (text == null || !context.mounted) return;

  final read = parseBackup(text);
  if (read is BackupReadFailed) {
    showUndoableFeedback(context, message: read.reason, undo: null);
    return;
  }

  final existing = await ref.read(timeEntryRepositoryProvider).readForBackup();
  final plan = planMerge(
    incoming: (read as BackupReadOk).file,
    existingEntries: existing.entries,
    existingActivities: existing.activities,
    now: ref.read(appClockProvider).nowUtc(),
  );
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ImportSheet(plan: plan),
  );
}

/// The dry run: what this file would add, update, skip — or why it cannot be
/// applied at all (SPEC §8.6).
class ImportSheet extends ConsumerStatefulWidget {
  const ImportSheet({required this.plan, super.key});

  final BackupPlan plan;

  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  bool _applying = false;

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ref.read(timelineWriterProvider).applyBackup(widget.plan);
      if (!mounted) return;
      Navigator.of(context).pop();
      showUndoableFeedback(
        context,
        message:
            'Imported ${widget.plan.added} new and '
            '${widget.plan.updated} updated entries',
        undo: null,
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Import backup',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Insets.md),
            if (plan.isApplicable) ...<Widget>[
              _Count(label: 'Added', value: plan.added),
              _Count(label: 'Updated', value: plan.updated),
              _Count(
                label: 'Skipped',
                value: plan.skipped,
                hint: 'already newer here',
              ),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: Radii.smAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'This file cannot be imported',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      plan.rejection!,
                      key: const Key('import-rejection'),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Insets.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: plan.isApplicable && !_applying ? _apply : null,
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, this.hint});

  final String label;
  final int value;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Insets.xs),
    child: Row(
      children: <Widget>[
        SizedBox(width: Metrics.fieldLabel, child: Text(label)),
        Text(
          '$value',
          style: AppType.numeric(Theme.of(context).textTheme.titleMedium),
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Everything, gone — and it asks you to type the word first (SPEC §8.6).
Future<void> confirmDeleteAll(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAllDialog(),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(timelineWriterProvider).deleteAllData();
  if (!context.mounted) return;
  showUndoableFeedback(context, message: 'All data deleted', undo: null);
}

class _DeleteAllDialog extends StatefulWidget {
  const _DeleteAllDialog();

  @override
  State<_DeleteAllDialog> createState() => _DeleteAllDialogState();
}

class _DeleteAllDialogState extends State<_DeleteAllDialog> {
  final _typed = TextEditingController();
  static const String _word = 'delete';

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete all data?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Every entry and activity is removed. This one is not undoable, so '
          'export a backup first if you might want it.',
        ),
        const SizedBox(height: Insets.md),
        TextField(
          key: const Key('delete-all-confirm'),
          controller: _typed,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Type "$_word"'),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: _typed.text.trim().toLowerCase() == _word
            ? () => Navigator.of(context).pop(true)
            : null,
        child: const Text('Delete everything'),
      ),
    ],
  );
}
