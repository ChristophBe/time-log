import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../entry/activity_input.dart';
import '../entry/entry_providers.dart';

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
  String title = 'Fill this gap',
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _FillGapSheet(
    startLocal: startLocal,
    endLocal: endLocal,
    duration: duration,
    use24h: use24h,
    title: title,
  ),
);

class _FillGapSheet extends ConsumerStatefulWidget {
  const _FillGapSheet({
    required this.startLocal,
    required this.endLocal,
    required this.duration,
    required this.use24h,
    required this.title,
  });

  final DateTime startLocal;
  final DateTime endLocal;
  final Duration duration;
  final bool use24h;
  final String title;

  @override
  ConsumerState<_FillGapSheet> createState() => _FillGapSheetState();
}

class _FillGapSheetState extends ConsumerState<_FillGapSheet> {
  final ActivityInputController _input = ActivityInputController();

  /// Enter fires both the key event and `onSubmitted`; popping twice would
  /// pop whatever is under the sheet.
  bool _done = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit(String name) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _input.listenable,
    builder: (context, _) => _buildSheet(context),
  );

  Widget _buildSheet(BuildContext context) {
    final suggestions =
        ref.watch(activityInputSuggestionsProvider(_input.query, null)).value ??
        const <ActivitySuggestion>[];
    final now = ref.watch(appClockProvider).nowUtc();
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
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Insets.xs),
            Text(
              '$range  ·  ${formatDuration(widget.duration)}',
              style: AppType.numeric(Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: Insets.lg),
            ActivityInputField(
              key: const Key('fill-gap-name'),
              controller: _input,
              suggestions: suggestions,
              onSubmit: _submit,
              autofocus: true,
              label: 'What were you doing?',
            ),
            Flexible(
              child: ActivityInputSuggestions(
                controller: _input,
                suggestions: suggestions,
                now: now,
                onPick: _submit,
                keyPrefix: 'fill-gap-suggestion',
              ),
            ),
            const SizedBox(height: Insets.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _input.isValid
                    ? () => _submit(_input.typedName)
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
