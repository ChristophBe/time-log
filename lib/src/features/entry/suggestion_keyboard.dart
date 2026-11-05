import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/repositories/time_entry_repository.dart';

/// The keyboard flow for a name field sitting over ranked suggestions
/// (SPEC §9.6, §10.1, §10.5).
///
/// Three surfaces ask the same question — the start composer about now
/// (SPEC §8.3), the activity picker about an entry (§6.10), filling a gap about
/// a span that has passed (§8.2) — and the arrows and Enter have to mean the
/// same thing in all of them. They each used to carry their own copy of this
/// switch, which is how two of them ended up clamping differently.
///
/// [highlighted] is the row Enter would take, or -1 for "use what is typed".
/// [onHighlight] is handed the new index rather than setting it, because one
/// caller keeps it in a `ValueNotifier` and another in `State`.
///
/// [onEscape] is optional: the composer has no modal to dismiss, so Escape
/// abandons what was typed and hands the screen back, while a sheet leaves
/// Escape to its own dismissal, which pops with null and changes nothing.
KeyEventResult handleSuggestionKey(
  KeyEvent event, {
  required List<ActivitySuggestion> suggestions,
  required int highlighted,
  required ValueChanged<int> onHighlight,
  required ValueChanged<ActivitySuggestion> onPickSuggestion,
  required VoidCallback onCommitTyped,
  VoidCallback? onEscape,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  switch (event.logicalKey) {
    case LogicalKeyboardKey.arrowDown:
      onHighlight(
        suggestions.isEmpty
            ? -1
            : (highlighted + 1).clamp(0, suggestions.length - 1),
      );
      return KeyEventResult.handled;
    case LogicalKeyboardKey.arrowUp:
      // Up off the top goes back to "what is typed" rather than stopping on the
      // first row: the field is where you came from.
      onHighlight(highlighted <= 0 ? -1 : highlighted - 1);
      return KeyEventResult.handled;
    case LogicalKeyboardKey.enter:
    case LogicalKeyboardKey.numpadEnter:
      if (highlighted >= 0 && highlighted < suggestions.length) {
        onPickSuggestion(suggestions[highlighted]);
      } else {
        onCommitTyped();
      }
      return KeyEventResult.handled;
    case LogicalKeyboardKey.escape:
      if (onEscape == null) return KeyEventResult.ignored;
      onEscape();
      return KeyEventResult.handled;
    default:
      return KeyEventResult.ignored;
  }
}
