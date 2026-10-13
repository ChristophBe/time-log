import 'package:flutter/cupertino.dart' show CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_info.dart';
import '../../app/design.dart';
import '../../app/platform_style.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/app_settings.dart';
import '../backup/backup_sheet.dart';
import '../export/export_sheet.dart';
import '../shortcuts/shortcuts_sheet.dart';

/// A minimal settings screen (part of SPEC §8.6).
///
/// Export/import, the continue window and the long-run threshold are P4; what is
/// here is what the editing in P3 needs.
///
/// One idiom per kind of choice: both "pick one of these" settings are
/// segmented buttons under a titled block, because two controls that ask the
/// same question should not look like two different questions.
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
        padding: const EdgeInsets.only(bottom: Insets.xl),
        children: <Widget>[
          const _SectionHeader('Editing'),
          _Choice<int>(
            title: 'Snap edits to',
            description:
                'Dragging a boundary rounds to this. Typed times are never '
                'rounded.',
            segments: <ButtonSegment<int>>[
              for (final minutes in AppSettings.snapChoicesMinutes)
                ButtonSegment<int>(
                  value: minutes,
                  label: Text(minutes == 0 ? 'Off' : '$minutes min'),
                ),
            ],
            selected: settings.snap.inMinutes,
            onChanged: (minutes) => repository.save(
              settings.copyWith(snap: Duration(minutes: minutes)),
            ),
          ),
          _Choice<int>(
            title: 'Offer Continue for',
            description:
                'After an entry ends, resuming it offers to extend it instead '
                'of starting a second one (SPEC §6.4).',
            segments: <ButtonSegment<int>>[
              for (final minutes in AppSettings.continueChoicesMinutes)
                ButtonSegment<int>(
                  value: minutes,
                  label: Text(minutes == 0 ? 'Off' : '$minutes min'),
                ),
            ],
            selected: settings.continueWindow.inMinutes,
            onChanged: (minutes) => repository.save(
              settings.copyWith(continueWindow: Duration(minutes: minutes)),
            ),
          ),
          _Choice<int>(
            title: 'Ask after',
            description:
                'How long something may run before the app asks whether you '
                'meant it.',
            segments: <ButtonSegment<int>>[
              for (final hours in AppSettings.longRunChoicesHours)
                ButtonSegment<int>(
                  value: hours,
                  label: Text(hours == 0 ? 'Never' : '$hours h'),
                ),
            ],
            selected: settings.longRun.inHours,
            onChanged: (hours) => repository.save(
              settings.copyWith(longRun: Duration(hours: hours)),
            ),
          ),
          const _SectionHeader('Display'),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            title: const Text('24-hour clock'),
            value: settings.use24HourClock,
            onChanged: (value) =>
                repository.save(settings.copyWith(use24HourClock: value)),
          ),
          _Choice<AppThemeMode>(
            title: 'Theme',
            segments: const <ButtonSegment<AppThemeMode>>[
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.system,
                label: Text('System'),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.light,
                label: Text('Light'),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.dark,
                label: Text('Dark'),
              ),
            ],
            selected: settings.themeMode,
            onChanged: (mode) =>
                repository.save(settings.copyWith(themeMode: mode)),
          ),
          _Choice<int>(
            title: 'Week starts on',
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 0, label: Text('System')),
              ButtonSegment<int>(value: DateTime.monday, label: Text('Mon')),
              ButtonSegment<int>(value: DateTime.sunday, label: Text('Sun')),
            ],
            selected: settings.firstDayOfWeek,
            onChanged: (day) =>
                repository.save(settings.copyWith(firstDayOfWeek: day)),
          ),
          _Choice<int>(
            title: 'Day height',
            description:
                'Where the calendar starts; pinch or zoom changes it '
                'for the moment, this changes where it comes back to.',
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 40, label: Text('Compact')),
              ButtonSegment<int>(value: 72, label: Text('Default')),
              ButtonSegment<int>(value: 120, label: Text('Tall')),
            ],
            selected: _nearestZoom(settings.pixelsPerHour),
            onChanged: (pixels) => repository.save(
              settings.copyWith(pixelsPerHour: pixels.toDouble()),
            ),
          ),
          const _SectionHeader('Data'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            title: const Text('Export entries…'),
            subtitle: const Text(
              'A CSV of a date range, for a spreadsheet or an invoice.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showExportSheet(context),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            title: const Text('Export everything'),
            subtitle: const Text(
              'A JSON backup of every entry, activity and setting.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => exportEverything(context, ref),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            title: const Text('Import a backup…'),
            subtitle: const Text(
              'Shows what it would change before changing anything.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => startImport(context, ref),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            title: Text(
              'Delete all data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Not undoable. Export a backup first.'),
            onTap: () => confirmDeleteAll(context, ref),
          ),
          const _SectionHeader('About'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            title: const Text('time-log'),
            subtitle: const Text(
              'Version $appVersion · the contract is SPEC.md in the repository',
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            title: const Text('Open-source licences'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'time-log',
              applicationVersion: appVersion,
            ),
          ),
          const _SectionHeader('Keyboard shortcuts'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            title: const Text('All shortcuts'),
            subtitle: const Text('Also on the ? key.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showShortcutsSheet(context),
          ),
        ],
      ),
    );
  }
}

/// A titled "pick one of these" block.
class _Choice<T extends Object> extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.description,
  });

  final String title;
  final String? description;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Insets.lg,
      Insets.sm,
      Insets.lg,
      Insets.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.bodyLarge),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: Insets.md),
        SizedBox(
          width: double.infinity,
          child: PlatformStyle.from(context).isApple
              // Apple's equivalent of a segmented button, and it fills its
              // width rather than hugging its labels, which is the convention
              // inside a grouped settings list.
              ? CupertinoSlidingSegmentedControl<T>(
                  groupValue: selected,
                  onValueChanged: (value) {
                    if (value != null) onChanged(value);
                  },
                  children: <T, Widget>{
                    for (final segment in segments)
                      // Cupertino's segments come out 35pt tall, which is under
                      // the 44pt minimum Apple itself asks for and SPEC §10.2
                      // requires. The constraint is a floor, so it still grows
                      // with the text scale.
                      segment.value: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Center(
                          widthFactor: 1,
                          child: segment.label ?? const SizedBox.shrink(),
                        ),
                      ),
                  },
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<T>(
                    segments: segments,
                    selected: <T>{selected},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        onChanged(selection.first),
                  ),
                ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Insets.lg,
      Insets.xl,
      Insets.lg,
      Insets.sm,
    ),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// The nearest offered day height to whatever zoom is stored.
///
/// The calendar's own zoom buttons move `pixelsPerHour` continuously, so the
/// stored value is usually not one of the three on offer; the control shows
/// the one it is closest to rather than nothing at all.
int _nearestZoom(double pixelsPerHour) {
  const options = <int>[40, 72, 120];
  var best = options.first;
  for (final option in options) {
    if ((option - pixelsPerHour).abs() < (best - pixelsPerHour).abs()) {
      best = option;
    }
  }
  return best;
}
