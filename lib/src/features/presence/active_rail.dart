import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../domain/presence/active_session.dart';
import '../../domain/timeline/clipping.dart';
import '../calendar/calendar_metrics.dart';
import 'presence_providers.dart';

/// Width of the stroke, which is about the only thing thinner than a label.
const double _railWidth = 3;

/// When the computer was in use, down the inner edge of the gutter (SPEC §8.2).
///
/// In the gutter because it describes the axis rather than an activity, and the
/// blocks keep every pixel they had. It is read, never edited, so it takes no
/// input: a drag aimed at a block must not be able to land here.
class ActiveRail extends ConsumerWidget {
  const ActiveRail({
    required this.metrics,
    required this.gutter,
    required this.now,
    required this.use24h,
    super.key,
  });

  final CalendarMetrics metrics;
  final double gutter;
  final DateTime now;
  final bool use24h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(daySessionsProvider).value ?? const <ActiveSession>[];
    final color = AppColors.from(context).activeRail;
    return Stack(
      children: <Widget>[
        for (final session in sessions)
          if (_slice(session) case final span?)
            Positioned(
              key: ValueKey<String>('active-rail-${session.id}'),
              top: metrics.offsetFor(span.start),
              left: gutter - _railWidth - 1,
              width: _railWidth,
              height: metrics.heightFor(span.end.difference(span.start)),
              child: IgnorePointer(
                child: Semantics(
                  label: _label(session),
                  child: ColoredBox(color: color),
                ),
              ),
            ),
      ],
    );
  }

  ClippedSpan? _slice(ActiveSession session) => clipSpan(
    start: session.startUtc,
    end: session.endOr(now),
    from: metrics.window.startUtc,
    to: metrics.window.endUtc,
  );

  String _label(ActiveSession session) {
    final start = formatTimeOfDay(session.startUtc.toLocal(), use24h: use24h);
    final length = formatDurationVerbose(
      session.endOr(now).difference(session.startUtc),
    );
    final end = session.endUtc;
    if (end == null) return 'At the computer since $start, $length';
    final to = formatTimeOfDay(end.toLocal(), use24h: use24h);
    return 'At the computer, $start to $to, $length';
  }
}
