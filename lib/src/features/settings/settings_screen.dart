import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import '../../domain/models/app_settings.dart';

/// A minimal settings screen (part of SPEC §8.6).
///
/// Export/import, the continue window and the long-run threshold are P4; what is
/// here is what the editing in P3 needs.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final repository = ref.watch(settingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('Editing'),
          ListTile(
            title: const Text('Snap edits to'),
            subtitle: const Text(
              'Dragging a boundary rounds to this. Typed times are never '
              'rounded.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: <ButtonSegment<int>>[
                for (final minutes in AppSettings.snapChoicesMinutes)
                  ButtonSegment<int>(
                    value: minutes,
                    label: Text(minutes == 0 ? 'Off' : '$minutes min'),
                  ),
              ],
              selected: <int>{settings.snap.inMinutes},
              onSelectionChanged: (selection) => repository.save(
                settings.copyWith(snap: Duration(minutes: selection.first)),
              ),
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader('Display'),
          SwitchListTile(
            title: const Text('24-hour clock'),
            value: settings.use24HourClock,
            onChanged: (value) =>
                repository.save(settings.copyWith(use24HourClock: value)),
          ),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<AppThemeMode>(
              value: settings.themeMode,
              onChanged: (mode) {
                if (mode == null) return;
                repository.save(settings.copyWith(themeMode: mode));
              },
              items: const <DropdownMenuItem<AppThemeMode>>[
                DropdownMenuItem<AppThemeMode>(
                  value: AppThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem<AppThemeMode>(
                  value: AppThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem<AppThemeMode>(
                  value: AppThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader('Keyboard shortcuts'),
          const _Shortcut(keys: 'Ctrl/Cmd + N', action: 'Start an activity'),
          const _Shortcut(keys: 'Ctrl/Cmd + .', action: 'Stop'),
          const _Shortcut(keys: 'Ctrl/Cmd + R', action: 'Resume the last one'),
          const _Shortcut(keys: 'Left / Right', action: 'Previous / next day'),
          const _Shortcut(keys: 'T', action: 'Today'),
          const _Shortcut(
            keys: 'Shift + Up / Down',
            action: 'Move the focused entry\'s end',
          ),
          const _Shortcut(
            keys: 'Alt + Up / Down',
            action: 'Move the focused entry\'s start',
          ),
          const _Shortcut(keys: 'Enter', action: 'Open the focused entry'),
          const _Shortcut(keys: 'Space', action: 'Resume the focused entry'),
          const _Shortcut(keys: 'Delete', action: 'Delete the focused entry'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(action),
    trailing: Text(keys, style: Theme.of(context).textTheme.labelMedium),
  );
}
