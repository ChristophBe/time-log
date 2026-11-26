import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/time_entry.dart';
import '../today/today_providers.dart';

part 'entry_providers.g.dart';

typedef EntryNeighbours = ({TimeEntry? previous, TimeEntry? next});

/// The entries on either side of [entryId], which decide whether a boundary is
/// shared or free (SPEC §7.1) and what a typed time would collide with.
@riverpod
Future<EntryNeighbours> entryNeighbours(Ref ref, String entryId) async {
  // Re-read whenever the timeline changes.
  ref.watch(runningEntryProvider);
  ref.watch(dayEntriesProvider);
  final repository = ref.watch(timeEntryRepositoryProvider);
  final entry = await repository.findEntry(entryId);
  if (entry == null) return (previous: null, next: null);
  return repository.neighboursOf(entryId, entry.startUtc);
}

/// Activities ranked against what has been typed (SPEC §9.6), for every place
/// an activity name is entered.
///
/// [excludeActivityId] is the one activity that would be a no-op to pick: the
/// running one when starting, the entry's own when relabelling it. Null where
/// every activity is a fair answer.
@riverpod
Stream<List<ActivitySuggestion>> activityInputSuggestions(
  Ref ref,
  String query,
  String? excludeActivityId,
) => ref
    .watch(timeEntryRepositoryProvider)
    .watchSuggestions(
      now: ref.watch(appClockProvider).nowUtc(),
      query: query,
      excludeActivityId: excludeActivityId,
    );
