import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../../app/shortcuts.dart';

/// Every keyboard shortcut, in one place (SPEC §10.5).
///
/// One list, three readers: the `?` sheet, the Settings screen and the macOS
/// menu bar. A shortcut that exists in the app but not in this list is a
/// shortcut nobody will find.
class Shortcut {
  const Shortcut(this.keys, this.action);

  final String keys;
  final String action;
}

List<Shortcut> appShortcuts() => <Shortcut>[
  Shortcut('$commandKeyLabel + N', 'Start an activity'),
  Shortcut('$commandKeyLabel + .', 'Stop'),
  Shortcut('$commandKeyLabel + R', 'Resume the last one'),
  Shortcut('$commandKeyLabel + F', 'Search history'),
  const Shortcut('Left / Right', 'Previous / next day'),
  const Shortcut('T', 'Today'),
  const Shortcut('Shift + Up / Down', "Move the focused entry's end"),
  const Shortcut('Alt + Up / Down', "Move the focused entry's start"),
  const Shortcut('Enter', 'Open the focused entry'),
  const Shortcut('Space', 'Resume the focused entry'),
  const Shortcut('Delete', 'Delete the focused entry'),
  const Shortcut('?', 'This list'),
];

Future<void> showShortcutsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ShortcutsSheet(),
    );

class ShortcutsSheet extends StatelessWidget {
  const ShortcutsSheet({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Keyboard shortcuts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Insets.md),
          for (final shortcut in appShortcuts())
            ShortcutRow(shortcut: shortcut),
        ],
      ),
    ),
  );
}

/// One shortcut, with its keys as keys.
class ShortcutRow extends StatelessWidget {
  const ShortcutRow({required this.shortcut, super.key});

  final Shortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(shortcut.action)),
          const SizedBox(width: Insets.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: Insets.xs / 2,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: Radii.smAll,
            ),
            child: Text(
              shortcut.keys,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
