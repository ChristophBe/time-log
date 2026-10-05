import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../../core/formatters.dart';
import '../../domain/models/activity.dart';

/// Asks what you were doing in a gap you just tapped (SPEC §8.2).
///
/// A name and nothing else, like the start composer: the times are already
/// decided — they are the gap's — and a note is a judgement made afterwards
/// on the entry itself (SPEC §8.3).
Future<String?> showFillGapSheet(
  BuildContext context, {
  required DateTime startLocal,
  required DateTime endLocal,
  required Duration duration,
  required bool use24h,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _FillGapSheet(
    startLocal: startLocal,
    endLocal: endLocal,
    duration: duration,
    use24h: use24h,
  ),
);

class _FillGapSheet extends StatefulWidget {
  const _FillGapSheet({
    required this.startLocal,
    required this.endLocal,
    required this.duration,
    required this.use24h,
  });

  final DateTime startLocal;
  final DateTime endLocal;
  final Duration duration;
  final bool use24h;

  @override
  State<_FillGapSheet> createState() => _FillGapSheetState();
}

class _FillGapSheetState extends State<_FillGapSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (!Activity.isValidName(name)) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final range =
        '${formatTimeOfDay(widget.startLocal, use24h: widget.use24h)} – '
        '${formatTimeOfDay(widget.endLocal, use24h: widget.use24h)}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Insets.lg,
          0,
          Insets.lg,
          Insets.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Fill this gap',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              '$range  ·  ${formatDuration(widget.duration)}',
              style: AppType.numeric(Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: Insets.lg),
            TextField(
              key: const Key('fill-gap-name'),
              controller: _name,
              autofocus: true,
              maxLength: Activity.maxNameLength,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'What were you doing?',
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: Activity.isValidName(_name.text.trim())
                    ? _submit
                    : null,
                child: const Text('Add entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
