import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/palette.dart';
import '../../core/clock.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/timeline_writer.dart';
import '../today/action_feedback.dart';
import '../today/today_providers.dart';
import 'activity_input.dart';
import 'entry_providers.dart';

/// Rename and recolour an activity (SPEC §6.7).
///
/// Renaming to a name that already exists is a **merge**: every entry moves to
/// the other activity and this one is dropped. That is stated here rather than
/// discovered, because it is the one action in the app that cannot be guessed
/// from its name — and it is undoable, like everything else.
Future<void> showActivityEditor(
  BuildContext context,
  WidgetRef ref,
  Activity activity,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ActivityEditor(activity: activity),
);

class ActivityEditor extends ConsumerStatefulWidget {
  const ActivityEditor({required this.activity, super.key});

  final Activity activity;

  @override
  ConsumerState<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends ConsumerState<ActivityEditor> {
  late final ActivityInputController _input = ActivityInputController(
    text: widget.activity.name,
  );
  late int _seed = widget.activity.colorSeed;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final writer = ref.read(timelineWriterProvider);
    final name = _input.typedName;
    final messages = <String>[];
    UndoToken? undo;

    if (_seed != widget.activity.colorSeed) {
      undo = await writer.setActivityColor(
        activityId: widget.activity.id,
        colorSeed: _seed,
      );
      messages.add('Recoloured');
    }
    if (name != widget.activity.name && Activity.isValidName(name)) {
      final result = await writer.renameActivity(
        activityId: widget.activity.id,
        name: name,
      );
      undo = result.undo;
      messages.add(
        result.activity.id == widget.activity.id
            ? 'Renamed to $name'
            : 'Merged into $name',
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (messages.isEmpty) return;
    showUndoableFeedback(context, message: messages.join(' · '), undo: undo);
  }

  /// The other activity that [name] would fold this one into, if any.
  Activity? _mergeTarget(String name, Map<String, Activity> activities) {
    final key = Activity.keyFor(name);
    for (final other in activities.values) {
      if (other.id != widget.activity.id && other.nameKey == key) return other;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _input.listenable,
    builder: (context, _) => _buildSheet(context),
  );

  Widget _buildSheet(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final suggestions =
        ref
            .watch(
              activityInputSuggestionsProvider(
                _input.query,
                widget.activity.id,
              ),
            )
            .value ??
        const <ActivitySuggestion>[];
    final now = ref.watch(appClockProvider).nowUtc();
    final target = _mergeTarget(
      _input.typedName,
      ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{},
    );

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
            Text('Activity', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Insets.md),
            ActivityInputField(
              key: const Key('activity-name'),
              controller: _input,
              suggestions: suggestions,
              // Enter confirms the name; a suggestion fills the field instead
              // (see onPick), because Save also carries the colour.
              onSubmit: (name) {
                _input.fill(name);
                return _save();
              },
              label: 'Name',
              helper: target == null
                  ? 'An existing name merges the two together.'
                  : 'Merges into “${target.name}”: every entry moves over.',
            ),
            Flexible(
              child: ActivityInputSuggestions(
                controller: _input,
                suggestions: suggestions,
                now: now,
                onPick: _input.fill,
                keyPrefix: 'editor-suggestion',
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text('Colour', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                for (var seed = 0; seed < ActivityPalette.length; seed++)
                  _Swatch(
                    seed: seed,
                    selected: seed == _seed,
                    brightness: brightness,
                    onTap: () => setState(() => _seed = seed),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _input.isValid ? _save : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.seed,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  final int seed;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ActivityPalette.forSeed(seed, brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Colour ${seed + 1}',
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.pill,
        child: SizedBox(
          width: kMinTapTarget,
          height: kMinTapTarget,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.edge : Colors.transparent,
                  width: Strokes.focus,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 18, color: colors.onFill)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
