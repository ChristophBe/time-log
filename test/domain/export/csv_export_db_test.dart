import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/export/csv_export.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/timeline/day_totals.dart';
import 'package:time_log/src/domain/timeline/day_window.dart';

import '../../support/fixtures.dart';

/// The export against a real database, because the half-open range lives in SQL
/// (`entriesInRange`) and the clipping lives in Dart, and the two have to agree
/// about which entries exist before the file can be right.
void main() {
  late TimelineHarness h;

  setUp(() => h = TimelineHarness(startAt: DateTime.utc(2026, 3, 10, 9)));
  tearDown(() => h.close());

  Future<Map<String, Activity>> activities() =>
      h.repository.watchActivitiesById().first;

  Future<CsvExport> exportBetween(DateTime from, DateTime to) async => buildCsv(
    entries: await h.repository.watchEntriesInRange(from, to).first,
    activities: await activities(),
    fromUtc: from,
    toUtc: to,
    now: h.now,
  );

  test('a day of real tracking comes back as rows that add up', () async {
    await h.writer.startByName(name: 'Writing specs');
    h.clock.advance(const Duration(minutes: 90));
    await h.writer.startByName(name: 'Email');
    h.clock.advance(const Duration(minutes: 30));
    await h.writer.stop();
    h.clock.advance(const Duration(minutes: 15));
    await h.writer.startByName(name: 'Code review');
    h.clock.advance(const Duration(minutes: 45));

    final from = DateTime.utc(2026, 3, 10);
    final to = DateTime.utc(2026, 3, 11);
    final csv = await exportBetween(from, to);

    expect(csv.rowCount, 3);
    expect(csv.total, const Duration(minutes: 90 + 30 + 45));
    expect(csv.text, contains('Writing specs'));
    expect(csv.text, contains('Code review'));
  });

  test('the export agrees with the day total the header shows', () async {
    // The property that matters most: two numbers for the same day, computed by
    // different code, from the same entries (SPEC §5.3, §8.6).
    await h.writer.startByName(name: 'Writing specs');
    h.clock.advance(const Duration(minutes: 50));
    await h.writer.stop();
    h.clock.advance(const Duration(minutes: 20));
    await h.writer.startByName(name: 'Email');
    h.clock.advance(const Duration(minutes: 25));

    final window = DayWindow(
      startUtc: DateTime.utc(2026, 3, 10),
      endUtc: DateTime.utc(2026, 3, 11),
      year: 2026,
      month: 3,
      day: 10,
    );
    final entries = await h.repository
        .watchEntriesInRange(window.startUtc, window.endUtc)
        .first;
    final totals = computeDayTotals(
      entries: entries,
      window: window,
      now: h.now,
    );
    final csv = await exportBetween(window.startUtc, window.endUtc);

    expect(csv.total, totals.tracked);
  });

  test('an entry crossing midnight is split across two exports', () async {
    // It began on the 10th and ended on the 11th; each export gets its own
    // slice and neither double-counts the other's.
    await h.writer.startByName(name: 'Night shift');
    h.clock.advance(const Duration(hours: 18)); // 09:00 -> 03:00 next day
    await h.writer.stop();

    final first = await exportBetween(
      DateTime.utc(2026, 3, 10),
      DateTime.utc(2026, 3, 11),
    );
    final second = await exportBetween(
      DateTime.utc(2026, 3, 11),
      DateTime.utc(2026, 3, 12),
    );

    expect(first.rowCount, 1);
    expect(second.rowCount, 1);
    expect(
      first.total + second.total,
      const Duration(hours: 18),
      reason: 'the two slices are the whole entry, counted once',
    );
  });

  test('a day with nothing on it exports no rows', () async {
    await h.writer.startByName(name: 'Writing specs');
    h.clock.advance(const Duration(hours: 1));
    await h.writer.stop();

    final csv = await exportBetween(
      DateTime.utc(2026, 3, 20),
      DateTime.utc(2026, 3, 21),
    );
    expect(csv.isEmpty, isTrue);
  });

  test('a deleted entry is not exported', () async {
    await h.writer.startByName(name: 'Mistake');
    h.clock.advance(const Duration(minutes: 30));
    await h.writer.stop();
    final entries = await h.entries();
    await h.writer.delete(entries.single.id);

    final csv = await exportBetween(
      DateTime.utc(2026, 3, 10),
      DateTime.utc(2026, 3, 11),
    );
    expect(csv.isEmpty, isTrue, reason: 'soft-deleted rows are not data');
  });

  test('the running entry is exported open-ended', () async {
    await h.writer.startByName(name: 'Writing specs');
    h.clock.advance(const Duration(minutes: 40));

    final csv = await exportBetween(
      DateTime.utc(2026, 3, 10),
      DateTime.utc(2026, 3, 11),
    );
    final row = csv.text.split('\r\n')[1];
    expect(csv.total, const Duration(minutes: 40));
    expect(row.endsWith(',,40,Europe/Berlin'), isTrue, reason: 'empty end_utc');
  });
}
