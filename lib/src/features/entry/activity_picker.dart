import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/glass.dart';
import '../../app/platform_style.dart';
import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline_writer.dart';
import '../today/action_feedback.dart';
import 'activity_editor.dart';
import 'activity_suggestion_row.dart';
import 'entry_providers.dart';

/// Changes which activity one entry belongs to (SPEC §6.10).
///
/// Deliberately the same shape as the start composer — a name field over the
/// §9.6 suggestions — because it is the same question ("what was this?") asked
/// about a span that has already happened. Typing a name nothing matches
/// creates it, so creating is never a mode (SPEC §8.3).
///
/// Renaming the activity for *all* history (SPEC §6.7) is the footer row rather
/// than the headline. Both edits start from the same tap on the entry sheet, and
/// this is the one that is usually meant; the other one is a step further in and
/// says what it will touch.
///
/// Returns true when the entry was relabelled, so the caller can close the sheet
/// it was opened from.
Future<bool> showActivityPicker(
  BuildContext context, {
  required TimeEntry entry,
  required Activity current,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ActivityPicker(entry: entry, current: current),
    ) ??
    false;

class ActivityPicker extends ConsumerStatefulWidget {
  const ActivityPicker({required this.entry, required this.current, super.key});

  final TimeEntry entry;
  final Activity current;

  @override
  ConsumerState<ActivityPicker> createState() => _ActivityPickerState();
}

class _ActivityPickerState extends ConsumerState<ActivityPicker> {
  final TextEditingController _name = TextEditingController();

  /// Which suggestion Enter would pick. -1 means "use what is typed".
  int _highlighted = -1;

  /// A physical Enter fires both `onSubmitted` and the raw key event, and a
  /// double tap on a row arrives twice. Either would write twice.
  bool _committing = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _commit(String name) async {
    if (_committing || !Activity.isValidName(name)) return;
    _committing = true;
    try {
      final writer = ref.read(timelineWriterProvider);
      final result = await writer.setEntryActivity(
        entryId: widget.entry.id,
        name: name,
      );
      if (!mounted) return;
      final undo = result.undo;
      // Nothing was written, so there is nothing to announce and nothing for
      // the entry sheet to close over (SPEC §6.10).
      Navigator.of(context).pop(undo != null);
      if (undo == null) return;
      showUndoableFeedback(
        context,
        message: 'Changed to ${result.activity.name}',
        undo: undo,
      );
    } finally {
      _committing = false;
    }
  }

  /// SPEC §6.7, reached from here so that the two edits are told apart at the
  /// moment of choosing rather than guessed at from the entry sheet.
  void _rename() {
    Navigator.of(context).pop(false);
    showActivityEditor(context, ref, widget.current);
  }

  /// The composer's keyboard flow, so the picker is usable without a pointer
  /// (SPEC §10.1, §10.5).
  KeyEventResult _onKey(List<ActivitySuggestion> suggestions, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(
          () => _highlighted = suggestions.isEmpty
              ? -1
              : (_highlighted + 1).clamp(0, suggestions.length - 1),
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(
          () => _highlighted = _highlighted <= 0 ? -1 : _highlighted - 1,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (_highlighted >= 0 && _highlighted < suggestions.length) {
          _commit(suggestions[_highlighted].activity.name);
        } else {
          _commit(_name.text.trim());
        }
        return KeyEventResult.handled;
      default:
        // Escape is left to the sheet's own dismissal, which pops with null and
        // therefore changes nothing.
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        ref
            .watch(relabelSuggestionsProvider(widget.current.id, _name.text))
            .value ??
        const <ActivitySuggestion>[];
    final now = ref.watch(appClockProvider).nowUtc();
    final scheme = Theme.of(context).colorScheme;

    return GlassSurface(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PlatformStyle.from(context).sheetRadius),
      ),
      edge: GlassEdge.top,
      opacity: 0.88,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  0,
                  Insets.lg,
                  Insets.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Change activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      // Which entry this is about, since the sheet it came from
                      // is now behind this one.
                      'This entry only — currently ${widget.current.name}.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: Insets.md),
                    Focus(
                      onKeyEvent: (_, event) => _onKey(suggestions, event),
                      child: TextField(
                        key: const Key('activity-picker-name'),
                        controller: _name,
                        autofocus: true,
                        maxLength: Activity.maxNameLength,
                        textInputAction: TextInputAction.done,
                        // Retyping the highlight away: a new query reorders the
                        // list, so the row Enter would take is no longer the
                        // one that was highlighted.
                        onChanged: (_) => setState(() => _highlighted = -1),
                        onSubmitted: (_) => _commit(_name.text.trim()),
                        decoration: const InputDecoration(
                          labelText: 'What were you doing?',
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Flexible rather than fixed: the list is as tall as it needs to
              // be until the keyboard and the rest of the sheet have had their
              // share.
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) => ActivitySuggestionRow(
                    key: ValueKey<String>(
                      'picker-suggestion-${suggestions[index].activity.id}',
                    ),
                    suggestion: suggestions[index],
                    highlighted: index == _highlighted,
                    now: now,
                    onTap: () => _commit(suggestions[index].activity.name),
                  ),
                ),
              ),
              Divider(
                height: Strokes.hairline,
                thickness: Strokes.hairline,
                color: AppColors.from(context).hairline,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.md,
                  Insets.lg,
                  Insets.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('activity-picker-rename'),
                        onPressed: _rename,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(
                          'Rename or recolour “${widget.current.name}” '
                          'everywhere…',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    FilledButton(
                      key: const Key('activity-picker-commit'),
                      onPressed: Activity.isValidName(_name.text.trim())
                          ? () => _commit(_name.text.trim())
                          : null,
                      child: const Text('Change activity'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
