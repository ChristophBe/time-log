import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../data/repositories/active_session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/app_settings.dart';
import '../today/action_feedback.dart';
import 'presence_port.dart';
import 'presence_providers.dart';

/// The switch and what goes with it (SPEC §8.6, §9.9).
///
/// What it does to the app is said beside the switch rather than behind it: it
/// is the one setting that changes how the app starts and how it quits.
class ActiveTimeSettings extends ConsumerWidget {
  const ActiveTimeSettings({super.key});

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: Insets.lg,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final port = ref.watch(presencePortProvider);
    final needsApproval =
        ref.watch(loginItemStatusProvider).value ==
        LoginItemStatus.requiresApproval;

    return Column(
      children: <Widget>[
        SwitchListTile.adaptive(
          contentPadding: _padding,
          title: const Text('Track time at this computer'),
          subtitle: Text(
            port.isSupported
                ? 'Records when this Mac is unlocked and awake, and shows it '
                      'beside the day. It stays on this device. The app starts '
                      'at login and keeps running in the menu bar after you '
                      'close its window.'
                : 'Only available on macOS for now.',
          ),
          value: port.isSupported && settings.trackActiveTime,
          onChanged: port.isSupported
              ? (value) => ref
                    .read(settingsRepositoryProvider)
                    .save(settings.copyWith(trackActiveTime: value))
              : null,
        ),
        if (settings.trackActiveTime && needsApproval)
          ListTile(
            contentPadding: _padding,
            title: const Text('Allow in System Settings'),
            subtitle: const Text(
              'macOS is waiting for your approval, so the app will not start '
              'at login yet.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: port.openLoginItemSettings,
          ),
        if (port.isSupported)
          ListTile(
            contentPadding: _padding,
            title: const Text('Delete active-time history'),
            subtitle: const Text('Entries are not affected.'),
            onTap: () => _confirmDelete(context, ref),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete active-time history?'),
        content: const Text(
          'Every recorded active session is removed, and this cannot be '
          'undone. Your entries stay as they are.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(activeSessionRepositoryProvider).deleteAll();
    if (!context.mounted) return;
    showUndoableFeedback(
      context,
      message: 'Active-time history deleted',
      undo: null,
    );
  }
}
