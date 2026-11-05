import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/glass.dart';
import '../../app/platform_style.dart';
import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/activity.dart';
import 'activity_suggestion_row.dart';
import 'entry_providers.dart';
import 'suggestion_keyboard.dart';

/// Asks which activity something was, with the §9.6 suggestions under the field.
///
/// One sheet for the two places that ask it about time that has already passed:
/// filling a gap (SPEC §8.2) and relabelling an entry (§6.10). They were two
/// sheets, and the gap one had no suggestions at all — which was an omission
/// rather than a decision, since the ranking is most useful exactly when you are
/// naming something after the fact.
///
/// The start composer (§8.3) asks the same question about *now* and stays its
/// own docked control rather than a sheet, which is the whole point of it; it
/// shares this sheet's keyboard flow through [handleSuggestionKey].
///
/// Returns the chosen name, or null when the sheet was dismissed. Typing a name
/// nothing matches is a valid answer: creating is never a mode (§8.3).
///
/// [footer] is handed the sheet's own context so that it can pop itself, which
/// is how §6.7's rename-everywhere gets out of here.
Future<String?> showActivityNameSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String commitLabel,
  String? excludeActivityId,
  WidgetBuilder? footer,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ActivityNameSheet(
    title: title,
    subtitle: subtitle,
    commitLabel: commitLabel,
    excludeActivityId: excludeActivityId,
    footer: footer,
  ),
);

class _ActivityNameSheet extends ConsumerStatefulWidget {
  const _ActivityNameSheet({
    required this.title,
    required this.subtitle,
    required this.commitLabel,
    required this.excludeActivityId,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final String commitLabel;
  final String? excludeActivityId;
  final WidgetBuilder? footer;

  @override
  ConsumerState<_ActivityNameSheet> createState() => _ActivityNameSheetState();
}

class _ActivityNameSheetState extends ConsumerState<_ActivityNameSheet> {
  final TextEditingController _name = TextEditingController();

  /// Which suggestion Enter would pick. -1 means "use what is typed".
  int _highlighted = -1;

  /// A physical Enter fires both `onSubmitted` and the raw key event, and a
  /// double tap on a row arrives twice. Either would pop twice, and the second
  /// pop would take the sheet underneath this one with it.
  bool _popped = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _pick(String name) {
    if (_popped || !Activity.isValidName(name)) return;
    _popped = true;
    Navigator.of(context).pop(name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        ref
            .watch(
              relabelSuggestionsProvider(widget.excludeActivityId, _name.text),
            )
            .value ??
        const <ActivitySuggestion>[];
    final now = ref.watch(appClockProvider).nowUtc();
    final scheme = Theme.of(context).colorScheme;
    final footer = widget.footer;

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
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      // What this is about, since whatever it was opened from
                      // is now behind it.
                      widget.subtitle,
                      style: AppType.numeric(
                        Theme.of(context).textTheme.bodySmall,
                      )?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: Insets.md),
                    Focus(
                      onKeyEvent: (_, event) => handleSuggestionKey(
                        event,
                        suggestions: suggestions,
                        highlighted: _highlighted,
                        onHighlight: (index) =>
                            setState(() => _highlighted = index),
                        onPickSuggestion: (s) => _pick(s.activity.name),
                        onCommitTyped: () => _pick(_name.text.trim()),
                      ),
                      child: TextField(
                        key: const Key('activity-name-field'),
                        controller: _name,
                        autofocus: true,
                        maxLength: Activity.maxNameLength,
                        textInputAction: TextInputAction.done,
                        // Retyping the highlight away: a new query reorders the
                        // list, so the row Enter would take is no longer the
                        // one that was highlighted.
                        onChanged: (_) => setState(() => _highlighted = -1),
                        onSubmitted: (_) => _pick(_name.text.trim()),
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
                    onTap: () => _pick(suggestions[index].activity.name),
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
                    if (footer != null) ...<Widget>[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: footer(context),
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                    FilledButton(
                      key: const Key('activity-name-commit'),
                      onPressed: Activity.isValidName(_name.text.trim())
                          ? () => _pick(_name.text.trim())
                          : null,
                      child: Text(widget.commitLabel),
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
