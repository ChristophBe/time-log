import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import 'today_providers.dart';

/// What the user chose in the start sheet.
class StartRequest {
  const StartRequest({required this.name, this.note});

  final String name;
  final String? note;
}

/// The two-tap path to tracking (SPEC §8.1, §8.3): the FAB opens this, one tap
/// on a suggestion starts.
///
/// Keyboard-first by design: the field has focus on open, arrows move through
/// suggestions, Enter commits, Escape cancels.
Future<StartRequest?> showStartSheet(BuildContext context) =>
    showModalBottomSheet<StartRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _StartSheet(),
    );

class _StartSheet extends ConsumerStatefulWidget {
  const _StartSheet();

  @override
  ConsumerState<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends ConsumerState<_StartSheet> {
  final _controller = TextEditingController();
  final _noteController = TextEditingController();
  final _fieldFocus = FocusNode();
  String _query = '';
  bool _showNote = false;

  /// Which row Enter would pick. -1 means "use what is typed".
  int _highlighted = -1;

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _submitTyped() {
    final name = _controller.text.trim();
    if (!Activity.isValidName(name)) return;
    _finish(name);
  }

  void _finish(String name) {
    final note = _noteController.text.trim();
    Navigator.of(context)
        .pop(StartRequest(name: name, note: note.isEmpty ? null : note));
  }

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
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (_highlighted >= 0 && _highlighted < suggestions.length) {
          _finish(suggestions[_highlighted].activity.name);
        } else {
          _submitTyped();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        ref.watch(activitySuggestionsProvider(_query)).value ??
        const <ActivitySuggestion>[];
    final running = ref.watch(runningEntryProvider).value;
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final now = ref.watch(appClockProvider).nowUtc();

    final typed = _controller.text.trim();
    final isNewName =
        typed.isNotEmpty &&
        !suggestions.any((s) => s.activity.nameKey == Activity.keyFor(typed));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Focus(
                onKeyEvent: (_, event) => _onKey(suggestions, event),
                child: TextField(
                  controller: _controller,
                  focusNode: _fieldFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  decoration: const InputDecoration(
                    labelText: 'What are you doing?',
                    hintText: 'Type what you are doing',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    _query = value;
                    _highlighted = -1;
                  }),
                  onSubmitted: (_) => _submitTyped(),
                ),
              ),
              if (running != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    // The one and only warning before switching; Undo covers the
                    // rest (SPEC §8.3).
                    'Stops ${activities[running.activityId]?.name ?? 'the current activity'} '
                    'at ${formatTimeOfDay(now.toLocal(), use24h: settings.use24HourClock)}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_showNote)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 2000,
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showNote = true),
                    icon: const Icon(Icons.notes),
                    label: const Text('Add note'),
                  ),
                ),
              const SizedBox(height: 8),
              if (isNewName)
                ListTile(
                  key: const Key('start-sheet-create'),
                  leading: const Icon(Icons.add),
                  title: Text('Create "$typed"'),
                  onTap: _submitTyped,
                ),
              if (suggestions.isEmpty && typed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Type what you are doing to start tracking it.'),
                ),
              ...suggestions.asMap().entries.map(
                (entry) => _SuggestionRow(
                  suggestion: entry.value,
                  highlighted: entry.key == _highlighted,
                  use24h: settings.use24HourClock,
                  now: now,
                  onTap: () => _finish(entry.value.activity.name),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.highlighted,
    required this.use24h,
    required this.now,
    required this.onTap,
  });

  final ActivitySuggestion suggestion;
  final bool highlighted;
  final bool use24h;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ActivityPalette.forSeed(
      suggestion.activity.colorSeed,
      Theme.of(context).brightness,
    );
    final last = suggestion.lastUsed;
    final subtitle = last == null
        ? null
        : 'last ${formatDurationVerbose(now.difference(last))} ago';

    return ListTile(
      selected: highlighted,
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: colors.fill, shape: BoxShape.circle),
      ),
      title: Text(suggestion.activity.name),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: onTap,
    );
  }
}
