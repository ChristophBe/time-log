import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/design.dart';
import '../../app/palette.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline/day_totals.dart';
import '../../domain/timeline_writer.dart';
import '../entry/entry_sheet.dart';
import '../today/action_feedback.dart';
import '../today/resume_action.dart';
import '../today/today_providers.dart';
import 'history_providers.dart';

/// Everything you have tracked, newest first (SPEC §8.5).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'history search');

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _delete(TimeEntry entry) async {
    final undo = await ref.read(timelineWriterProvider).delete(entry.id);
    if (!mounted) return;
    showUndoableFeedback(context, message: 'Entry deleted', undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(historyDaysProvider);
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final filter = ref.watch(historyActivityFilterProvider);

    // The shortcut itself is global and lives in the shell (SPEC §10.5); this
    // is the half that knows where the cursor goes.
    ref.listen<int>(
      historySearchRequestProvider,
      (_, _) => _searchFocus.requestFocus(),
    );

    return Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _SearchBar(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (value) =>
                    ref.read(historyQueryProvider.notifier).set(value),
              ),
              if (activities.length > 1)
                _ActivityFilter(
                  activities: activities.values.toList(),
                  selected: filter,
                  onSelected: (id) =>
                      ref.read(historyActivityFilterProvider.notifier).set(id),
                ),
              Expanded(
                child: days.isEmpty
                    ? const _NothingFound()
                    : CustomScrollView(
                        slivers: <Widget>[
                          for (final day in days)
                            SliverMainAxisGroup(
                              slivers: <Widget>[
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _DayHeaderDelegate(
                                    day: day,
                                    now: ref.watch(appClockProvider).nowUtc(),
                                    context: context,
                                  ),
                                ),
                                SliverList.builder(
                                  itemCount: day.entries.length,
                                  itemBuilder: (context, index) {
                                    final entry = day.entries[index];
                                    return _HistoryRow(
                                      key: ValueKey<String>('row-${entry.id}'),
                                      entry: entry,
                                      activity: activities[entry.activityId],
                                      onDelete: () => _delete(entry),
                                    );
                                  },
                                ),
                              ],
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(Insets.lg),
                              child: Center(
                                child: OutlinedButton(
                                  onPressed: () => ref
                                      .read(historyMonthsProvider.notifier)
                                      .loadEarlier(),
                                  child: const Text('Load earlier months'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Insets.lg,
      Insets.md,
      Insets.lg,
      Insets.sm,
    ),
    child: TextField(
      key: const Key('history-search'),
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search activities and notes',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    ),
  );
}

/// Filter by activity, as chips: the set is small and already colour-coded.
class _ActivityFilter extends StatelessWidget {
  const _ActivityFilter({
    required this.activities,
    required this.selected,
    required this.onSelected,
  });

  final List<Activity> activities;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: Insets.sm),
          child: ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
        ),
        for (final activity in activities)
          Padding(
            padding: const EdgeInsets.only(right: Insets.sm),
            child: ChoiceChip(
              label: Text(activity.name),
              selected: selected == activity.id,
              onSelected: (isSelected) =>
                  onSelected(isSelected ? activity.id : null),
            ),
          ),
      ],
    ),
  );
}

/// A day's date and what it came to, pinned while its entries scroll past.
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({
    required this.day,
    required this.now,
    required BuildContext context,
  }) : _extent = MediaQuery.textScalerOf(context).scale(40);

  final HistoryDay day;
  final DateTime now;
  final double _extent;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final totals = computeDayTotals(
      entries: day.entries,
      window: day.window,
      now: now,
    );
    final date = DateTime(day.window.year, day.window.month, day.window.day);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      alignment: Alignment.centerLeft,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              DateFormat.yMMMEd().format(date),
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formatDuration(totals.tracked),
            style: AppType.numeric(Theme.of(context).textTheme.labelMedium)
                ?.copyWith(color: scheme.onSurfaceVariant),
            semanticsLabel: 'Tracked ${formatDurationVerbose(totals.tracked)}',
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate old) =>
      old.day != day || old.now != now || old._extent != _extent;
}

/// One entry: what it was, when, how long, and how to pick it back up.
class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.entry,
    required this.activity,
    required this.onDelete,
    super.key,
  });

  final TimeEntry entry;
  final Activity? activity;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final now = ref.watch(appClockProvider).nowUtc();
    final colors = ActivityPalette.forSeed(
      activity?.colorSeed ?? 0,
      Theme.of(context).brightness,
    );
    final use24h = settings.use24HourClock;
    final start = entry.startUtc.toLocal();
    final end = entry.endUtc?.toLocal();

    return Dismissible(
      key: ValueKey<String>('dismiss-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        onTap: () => showEntrySheet(context, entry),
        leading: Container(
          width: Metrics.colorDot,
          height: Metrics.colorDot,
          decoration: BoxDecoration(color: colors.edge, shape: BoxShape.circle),
        ),
        title: Text(
          activity?.name ?? 'Activity',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          <String>[
            '${formatTimeOfDay(start, use24h: use24h)} – '
                '${end == null ? 'now' : formatTimeOfDay(end, use24h: use24h)}',
            formatDuration(entry.durationAt(now)),
            if (entry.note != null && entry.note!.isNotEmpty) entry.note!,
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // The swipe has a non-gesture equivalent, as every gesture must
        // (SPEC §10.1): this menu carries delete, and resume, and open.
        trailing: _RowMenu(entry: entry, onDelete: onDelete),
      ),
    );
  }
}

class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.entry, required this.onDelete});

  final TimeEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MenuAnchor(
    builder: (context, controller, _) => IconButton(
      tooltip: 'Entry actions',
      icon: const Icon(Icons.more_vert_rounded),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
    menuChildren: <Widget>[
      MenuItemButton(
        leadingIcon: const Icon(Icons.play_arrow_rounded),
        onPressed: entry.isRunning
            ? null
            : () => resumeOrContinue(context, ref, entry),
        child: const Text('Resume'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.edit_outlined),
        onPressed: () => showEntrySheet(context, entry),
        child: const Text('Open'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
        child: const Text('Delete'),
      ),
    ],
  );
}

class _NothingFound extends ConsumerWidget {
  const _NothingFound();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searching = ref.watch(historyQueryProvider).trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              searching ? 'Nothing matches' : 'Nothing tracked yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              searching
                  ? 'Try fewer words, or a different activity.'
                  : 'Start something on Today and it will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
