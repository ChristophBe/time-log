import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../../app/palette.dart';
import '../../core/formatters.dart';
import '../../data/repositories/time_entry_repository.dart';

/// One ranked activity, as offered by the start composer (SPEC §8.3) and by the
/// entry sheet's activity picker (SPEC §8.4).
///
/// Shared by both because they are the same row doing the same job — name the
/// activity, show how long ago it was used, and say which one Enter would take.
/// Only what happens on a tap differs.
class ActivitySuggestionRow extends StatelessWidget {
  const ActivitySuggestionRow({
    required this.suggestion,
    required this.highlighted,
    required this.now,
    required this.onTap,
    super.key,
  });

  final ActivitySuggestion suggestion;
  final bool highlighted;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = ActivityPalette.forSeed(
      suggestion.activity.colorSeed,
      Theme.of(context).brightness,
    );
    final last = suggestion.lastUsed;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        // Highlight by surface, not by recolouring the name: the row's colour
        // belongs to its activity, and tinting the text would make two things
        // compete to say which row Enter would take.
        color: highlighted ? scheme.secondaryContainer : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: Metrics.colorDot,
              height: Metrics.colorDot,
              decoration: BoxDecoration(
                color: colors.edge,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                suggestion.activity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (last != null) ...<Widget>[
              const SizedBox(width: Insets.sm),
              Text(
                '${formatAge(now.difference(last))} ago',
                maxLines: 1,
                style: AppType.numeric(Theme.of(context).textTheme.labelSmall)
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
