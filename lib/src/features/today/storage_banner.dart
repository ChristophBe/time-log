import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../../data/db/database.dart';

/// "Storage here is temporary. Export to keep your data." (SPEC §9.5).
///
/// Dismissible, and shown wherever it is placed only while the browser has
/// given us nothing persistent. Silence would be the wrong default: an app that
/// looks like it is saving and is not is worse than one that says so.
class StorageBanner extends StatefulWidget {
  const StorageBanner({super.key});

  @override
  State<StorageBanner> createState() => _StorageBannerState();
}

class _StorageBannerState extends State<StorageBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: webStorageIsTemporary,
    builder: (context, temporary, _) {
      if (!temporary || _dismissed) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      return Container(
        margin: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: Radii.smAll,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Storage here is temporary. Export to keep your data.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded),
              color: scheme.onErrorContainer,
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      );
    },
  );
}
