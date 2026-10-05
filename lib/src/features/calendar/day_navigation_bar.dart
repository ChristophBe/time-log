import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/adaptive.dart';
import '../../app/design.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../today/today_providers.dart';

/// The top row of the day header: which day you are looking at, how much of it
/// is tracked, and how to get to another one (SPEC §8.2, §8.1).
///
/// The date is left-aligned and is the largest thing in the row, because it is
/// the row's subject; the controls are grouped at the trailing edge, because
/// they are all the same kind of thing. Settings is not among them any more —
/// it is a destination in the shell now (SPEC §8), which gives this row back
/// the width it had been short of. Every one of them is also reachable by
/// keyboard from TodayScreen; the buttons exist so that none of it requires a
/// swipe (SPEC §10.1).
///
/// The total sits beside the date because that is the one number worth reading
/// at a glance. It lives here rather than in a footer because the bottom edge
/// belongs to the start composer, which has to be reachable at all times.
class DayNavigationRow extends ConsumerWidget {
  const DayNavigationRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(selectedDayProvider);
    final now = ref.watch(appClockProvider).nowUtc();
    final isToday = window.contains(now);
    final date = DateTime(window.year, window.month, window.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.xs, Insets.xs, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  // The date is the title of the screen, so it is typography
                  // rather than a labelled control: no caret glyph beside it,
                  // because the row already ends in four icons and a fifth
                  // would read as a fifth button.
                  child: TextButton(
                    onPressed: () => _pickDate(context, ref, date),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                      ),
                      // The button now fills its share of the row, so it has to
                      // be told where the label goes: a title belongs at the
                      // leading edge, not in the middle of its own button.
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    child: Text(
                      _label(date, isToday: isToday, now: now),
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // The spoken form stays long: a screen reader has no
                      // width problem, and "Choose a date" is the hint that
                      // the visible caret used to give (SPEC §10.4).
                      semanticsLabel:
                          '${_spokenLabel(date, isToday: isToday)}. '
                          'Choose a date',
                    ),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                // Three parts title to two parts stat, both tight. At the
                // default text size the total's share is its natural width and
                // nothing scales; at 200% nothing fits beside four buttons, and
                // then it is the stat that shrinks rather than the title that
                // truncates.
                const Expanded(flex: 2, child: _TrackedTotal()),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () =>
                ref.read(selectedDayProvider.notifier).previousDay(),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => ref.read(selectedDayProvider.notifier).nextDay(),
          ),
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today_outlined),
            // Disabled rather than hidden, so the control does not move about.
            onPressed: isToday
                ? null
                : () => ref.read(selectedDayProvider.notifier).today(),
          ),
        ],
      ),
    );
  }

  /// What the header says.
  ///
  /// Four icon buttons and the day's total leave about 130dp for this on a
  /// phone, and "Today, Tue, Mar 10" needs rather more than that — the title
  /// was ellipsising at the default text size, which is the one thing a title
  /// must not do. So it says the shortest complete answer to "which day am I
  /// looking at": **Today**, or the date without the year when the year is this
  /// one. The full date is a tap away in the picker and is always in the
  /// spoken label, so nothing is actually lost.
  static String _label(
    DateTime date, {
    required bool isToday,
    required DateTime now,
  }) {
    if (isToday) return 'Today';
    if (date.year != now.toLocal().year) {
      return DateFormat.yMMMEd().format(date);
    }
    return DateFormat.MMMEd().format(date);
  }

  static String _spokenLabel(DateTime date, {required bool isToday}) => isToday
      ? 'Today, ${DateFormat.yMMMEd().format(date)}'
      : DateFormat.yMMMEd().format(date);

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final picked = await showAdaptiveDatePicker(
      context,
      initial: current,
      first: DateTime(2000),
      last: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(selectedDayProvider.notifier).goToDate(picked);
  }
}

/// The day's tracked total, as a small stat beside the date.
///
/// Its own widget so that the 30-second coarse tick behind [dayTotalsProvider]
/// rebuilds this text alone and not the whole row (SPEC §9.4, §11.4).
class _TrackedTotal extends ConsumerWidget {
  const _TrackedTotal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracked = ref.watch(dayTotalsProvider).tracked;
    final scheme = Theme.of(context).colorScheme;
    // Scaled down rather than ellipsised when the row is tight: half a total
    // ("2 h 1…") is no use to anyone, and this is the same trick the elapsed
    // readout uses for the same reason.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.xs / 2,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: Radii.pill,
        ),
        child: Text(
          formatDuration(tracked),
          maxLines: 1,
          softWrap: false,
          style: AppType.numeric(Theme.of(context).textTheme.labelMedium)
              ?.copyWith(color: scheme.onSurfaceVariant),
          semanticsLabel: 'Tracked ${formatDurationVerbose(tracked)}',
        ),
      ),
    );
  }
}
