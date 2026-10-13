import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/glass.dart';
import '../../app/platform_style.dart';
import 'calendar_providers.dart';

/// Zoom, as a pair of buttons floating over the top-right of the day.
///
/// It sits on the calendar rather than in the header for two reasons: zoom acts
/// on the thing underneath it, and the header is for the day, not for the view
/// of it. Pinch does the same thing on touch, so this is the non-gesture
/// equivalent, not an extra (SPEC §10.1) -- which is why it is always on
/// screen and never behind a menu.
class CalendarZoomControl extends ConsumerWidget {
  const CalendarZoomControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = PlatformStyle.from(context);
    // It already floats over the day, which is exactly where glass belongs.
    final radius = style.glass
        ? Radii.pill
        : BorderRadius.circular(style.controlRadius);
    return Padding(
      padding: const EdgeInsets.all(Insets.sm),
      child: GlassSurface(
        borderRadius: radius,
        edge: GlassEdge.all,
        child: Material(
          color: style.glass
              ? Colors.transparent
              : scheme.surfaceContainerHigh.withValues(alpha: 0.92),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Zoom in',
                icon: const Icon(Icons.add_rounded, size: 20),
                onPressed: () =>
                    ref.read(calendarZoomProvider.notifier).zoomIn(),
              ),
              Divider(
                height: Strokes.hairline,
                thickness: Strokes.hairline,
                indent: Insets.sm,
                endIndent: Insets.sm,
              ),
              IconButton(
                tooltip: 'Zoom out',
                icon: const Icon(Icons.remove_rounded, size: 20),
                onPressed: () =>
                    ref.read(calendarZoomProvider.notifier).zoomOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
