import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/clock.dart';
import '../today/today_providers.dart';
import 'calendar_providers.dart';

/// Date header with previous/next, a date picker, Today, and zoom (SPEC §8.2).
///
/// Every one of these is also reachable by keyboard from TodayScreen; the
/// buttons exist so none of it requires a swipe or a pinch (SPEC §10.1).
class DayNavigationBar extends ConsumerWidget {
  const DayNavigationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(selectedDayProvider);
    final now = ref.watch(appClockProvider).nowUtc();
    final isToday = window.contains(now);
    final date = DateTime(window.year, window.month, window.day);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Previous day',
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  ref.read(selectedDayProvider.notifier).previousDay(),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => _pickDate(context, ref, date),
                child: Text(
                  isToday
                      ? 'Today, ${DateFormat.MMMEd().format(date)}'
                      : DateFormat.yMMMEd().format(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next day',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => ref.read(selectedDayProvider.notifier).nextDay(),
            ),
            IconButton(
              tooltip: 'Today',
              icon: const Icon(Icons.today),
              // Disabled rather than hidden, so the control does not move about.
              onPressed: isToday
                  ? null
                  : () => ref.read(selectedDayProvider.notifier).today(),
            ),
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.zoom_out),
              onPressed: () =>
                  ref.read(calendarZoomProvider.notifier).zoomOut(),
            ),
            IconButton(
              tooltip: 'Zoom in',
              icon: const Icon(Icons.zoom_in),
              onPressed: () => ref.read(calendarZoomProvider.notifier).zoomIn(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(selectedDayProvider.notifier).goToDate(picked);
  }
}
