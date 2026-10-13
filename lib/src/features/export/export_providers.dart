import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/export/csv_export.dart';
import 'delivery/delivery.dart';

part 'export_providers.g.dart';

/// A half-open range of instants, `[from, to)`. A record, so two ranges with
/// the same bounds are the same provider argument.
typedef ExportRange = ({DateTime from, DateTime to});

/// How the file leaves the app — a download on the web, the share sheet
/// everywhere else (SPEC §8.6). A provider so a test can watch an export
/// happen without a platform channel on the other end.
@Riverpod(keepAlive: true)
ExportDelivery exportDelivery(Ref ref) => createDelivery();

/// The extract for [range], assembled but not yet delivered.
///
/// Read once rather than watched: an export is a snapshot of a moment, and a
/// preview that shifted under the Export button while you read it would be
/// describing a different file from the one you got.
@riverpod
Future<CsvExport> rangeExport(Ref ref, ExportRange range) async {
  final repository = ref.watch(timeEntryRepositoryProvider);
  final entries = await repository
      .watchEntriesInRange(range.from, range.to)
      .first;
  final activities = await repository.watchActivitiesById().first;
  return buildCsv(
    entries: entries,
    activities: activities,
    fromUtc: range.from,
    toUtc: range.to,
    now: ref.watch(appClockProvider).nowUtc(),
  );
}
