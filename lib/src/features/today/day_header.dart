import 'package:flutter/material.dart';

import '../../app/design.dart';
import '../../app/glass.dart';
import '../../app/platform_style.dart';
import '../../app/theme.dart';
import '../calendar/day_navigation_bar.dart';
import 'long_run_banner.dart';
import 'running_band.dart';
import 'storage_banner.dart';

/// The top of Today: one surface carrying the day and what is running on it.
///
/// This replaces an app bar, a floating card and a toolbar that used to stack
/// here -- four surfaces with four backgrounds and no hierarchy between them.
/// An app bar whose only contents are a fixed title and one icon is a band of
/// chrome that tells you nothing; the date is the real title of this screen, so
/// it says the date instead.
class DayHeader extends StatelessWidget {
  const DayHeader({
    required this.onStop,
    required this.onResumeLast,
    required this.onFixStart,
    super.key,
  });

  final VoidCallback onStop;
  final VoidCallback onResumeLast;
  final VoidCallback onFixStart;

  @override
  Widget build(BuildContext context) {
    final style = PlatformStyle.from(context);
    final content = SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const DayNavigationRow(),
          RunningBand(
            onStop: onStop,
            onResumeLast: onResumeLast,
            onFixStart: onFixStart,
          ),
          // Below the band, because it is about the thing the band is showing
          // (SPEC §8.1).
          const LongRunBanner(),
          const StorageBanner(),
          // A glass header needs no rule under it: the material is what says
          // where the chrome stops, and a line there is the thing Liquid Glass
          // does away with (SPEC §9.8).
          if (!style.glass)
            Container(
              height: Strokes.hairline,
              color: AppColors.from(context).hairline,
            ),
        ],
      ),
    );

    if (!style.glass) {
      // No tone of its own: the header, the day and the composer are all one
      // surface, and a hairline is enough to say where the chrome stops.
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: content,
      );
    }
    return GlassSurface(
      edge: GlassEdge.bottom,
      child: Material(color: Colors.transparent, child: content),
    );
  }
}
