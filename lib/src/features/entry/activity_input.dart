import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/activity.dart';
import 'activity_suggestion_row.dart';

/// What the field and its suggestions share (SPEC §8.3, §9.6).
///
/// The field and the list are separate widgets because they do not always sit
/// together: the start composer docks the field at the bottom of Today and
/// raises the list over the calendar, while the sheets put the list straight
/// under the field. Whatever was typed, what has focus and which row is
/// highlighted therefore lives above both. The owner disposes it.
class ActivityInputController {
  ActivityInputController({String text = '', String? debugLabel})
    : text = TextEditingController(text: text),
      focus = FocusNode(debugLabel: debugLabel),
      highlighted = ValueNotifier<int>(-1);

  final TextEditingController text;
  final FocusNode focus;

  /// Which suggestion Enter would pick. -1 means "use what is typed".
  final ValueNotifier<int> highlighted;

  /// Rebuilds anything that cares about any of the three.
  Listenable get listenable =>
      Listenable.merge(<Listenable>[text, focus, highlighted]);

  String get query => text.text;

  String get typedName => text.text.trim();

  bool get isValid => Activity.isValidName(typedName);

  /// Puts [name] in the field with the caret after it, for callers where
  /// choosing a suggestion fills the field rather than committing.
  void fill(String name) {
    text.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    highlighted.value = -1;
  }

  void reset() {
    text.clear();
    highlighted.value = -1;
  }

  void dispose() {
    text.dispose();
    focus.dispose();
    highlighted.dispose();
  }
}

/// The one place an activity name is typed (SPEC §8.3).
///
/// A name field with the keyboard flow every such field shares: Arrow Down/Up
/// walk the suggestions, Enter takes the highlighted one or else what was typed
/// (SPEC §10.1, §10.5). Typing a name nothing matches is fine -- creating an
/// activity is never a mode -- so [onSubmit] always gets a valid name.
class ActivityInputField extends StatefulWidget {
  const ActivityInputField({
    required this.controller,
    required this.suggestions,
    required this.onSubmit,
    required this.label,
    this.hint,
    this.helper,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.onEscape,
    this.onChanged,
    super.key,
  });

  final ActivityInputController controller;

  /// The rows Enter and the arrows act on; the same list the owner renders.
  final List<ActivitySuggestion> suggestions;

  /// Called with a valid name, from Enter, the keyboard's action button, or
  /// [ActivityInputSuggestions.onPick]. While the future it returns is pending
  /// further submissions are dropped: a physical Enter fires both the raw key
  /// event and `onSubmitted`, and either would otherwise write twice.
  final FutureOr<void> Function(String name) onSubmit;

  final String label;
  final String? hint;
  final String? helper;
  final bool autofocus;
  final TextInputAction textInputAction;

  /// When given, Escape calls it. Left null, Escape is the surrounding sheet's
  /// to handle.
  final VoidCallback? onEscape;
  final VoidCallback? onChanged;

  @override
  State<ActivityInputField> createState() => _ActivityInputFieldState();
}

class _ActivityInputFieldState extends State<ActivityInputField> {
  bool _submitting = false;

  ActivityInputController get _c => widget.controller;

  Future<void> _submit(String name) async {
    if (_submitting || !Activity.isValidName(name)) return;
    _submitting = true;
    try {
      await widget.onSubmit(name);
    } finally {
      _submitting = false;
    }
  }

  void _submitHighlightedOrTyped() {
    final suggestions = widget.suggestions;
    final index = _c.highlighted.value;
    if (index >= 0 && index < suggestions.length) {
      _submit(suggestions[index].activity.name);
    } else {
      _submit(_c.typedName);
    }
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final highlighted = _c.highlighted;
    final count = widget.suggestions.length;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        highlighted.value = count == 0
            ? -1
            : (highlighted.value + 1).clamp(0, count - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        highlighted.value = highlighted.value <= 0 ? -1 : highlighted.value - 1;
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        final onEscape = widget.onEscape;
        if (onEscape == null) return KeyEventResult.ignored;
        onEscape();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _submitHighlightedOrTyped();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) => _onKey(event),
    child: TextField(
      controller: _c.text,
      focusNode: _c.focus,
      autofocus: widget.autofocus,
      maxLength: Activity.maxNameLength,
      textInputAction: widget.textInputAction,
      // A new query reorders the list, so the row Enter would take is no longer
      // the one that was highlighted.
      onChanged: (_) {
        _c.highlighted.value = -1;
        widget.onChanged?.call();
      },
      onSubmitted: (_) => _submit(_c.typedName),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        // The field is the only control; a character counter under it would
        // just add a line of noise.
        counterText: '',
      ),
    ),
  );
}

/// The ranked suggestions for an [ActivityInputField], as a list.
///
/// Shrink-wrapped, so the caller decides how much room it gets (wrap it in
/// `Flexible`). Rows are keyed `<keyPrefix>-<activity id>`.
class ActivityInputSuggestions extends StatelessWidget {
  const ActivityInputSuggestions({
    required this.controller,
    required this.suggestions,
    required this.now,
    required this.onPick,
    this.keyPrefix = 'suggestion',
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final ActivityInputController controller;
  final List<ActivitySuggestion> suggestions;
  final DateTime now;
  final void Function(String name) onPick;
  final String keyPrefix;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ListView.builder(
    shrinkWrap: true,
    padding: padding,
    itemCount: suggestions.length,
    itemBuilder: (context, index) => ValueListenableBuilder<int>(
      valueListenable: controller.highlighted,
      builder: (context, highlighted, _) => ActivitySuggestionRow(
        key: ValueKey<String>('$keyPrefix-${suggestions[index].activity.id}'),
        suggestion: suggestions[index],
        highlighted: index == highlighted,
        now: now,
        onTap: () => onPick(suggestions[index].activity.name),
      ),
    ),
  );
}
