import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/export/csv_export.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/time_entry.dart';

/// SPEC §8.6: the range extract.
void main() {
  // A UTC range, so the test reasons about instants rather than about the
  // machine's time zone. The local columns are checked separately.
  final from = DateTime.utc(2026, 3, 10);
  final to = DateTime.utc(2026, 3, 11);
  final now = DateTime.utc(2026, 3, 10, 15);

  const specs = Activity(id: 'a1', name: 'Writing specs', colorSeed: 0);
  const email = Activity(id: 'a2', name: 'Email', colorSeed: 1);
  const activities = <String, Activity>{'a1': specs, 'a2': email};

  TimeEntry entry({
    required String id,
    required DateTime start,
    DateTime? end,
    String activityId = 'a1',
    String? note,
  }) => TimeEntry(
    id: id,
    activityId: activityId,
    startUtc: start,
    endUtc: end,
    tzName: 'Europe/Berlin',
    note: note,
  );

  CsvExport export(List<TimeEntry> entries) => buildCsv(
    entries: entries,
    activities: activities,
    fromUtc: from,
    toUtc: to,
    now: now,
  );

  /// The rows without the BOM, the header or the trailing blank.
  List<String> rowsOf(CsvExport csv) =>
      csv.text.split('\r\n').skip(1).where((line) => line.isNotEmpty).toList();

  List<String> fieldsOf(String row) {
    // Enough of a parser for these tests: fields are either quoted or plain.
    final fields = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < row.length; i++) {
      final c = row[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < row.length && row[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          buffer.write(c);
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }

  group('the header', () {
    test('is exactly the columns SPEC §8.6 names, in order', () {
      final csv = export(<TimeEntry>[]);
      final header = csv.text.split('\r\n').first.replaceFirst('﻿', '');
      expect(header, csvColumns.join(','));
    });

    test('carries a BOM and CRLF, so Excel reads it', () {
      final csv = export(<TimeEntry>[
        entry(
          id: 'e1',
          start: DateTime.utc(2026, 3, 10, 9),
          end: DateTime.utc(2026, 3, 10, 10),
          activityId: 'a2',
        ),
      ]);
      expect(csv.text.codeUnitAt(0), 0xFEFF);
      expect(csv.text, contains('\r\n'));
    });

    test('an empty range is the header and nothing else', () {
      final csv = export(<TimeEntry>[]);
      expect(rowsOf(csv), isEmpty);
      expect(csv.isEmpty, isTrue);
      expect(csv.total, Duration.zero);
    });
  });

  group('clipping to the range (SPEC §5.3)', () {
    test('an entry that began before the range starts at the range', () {
      final csv = export(<TimeEntry>[
        entry(
          id: 'e1',
          start: DateTime.utc(2026, 3, 9, 23),
          end: DateTime.utc(2026, 3, 10, 1),
        ),
      ]);
      final fields = fieldsOf(rowsOf(csv).single);
      expect(fields[5], DateTime.utc(2026, 3, 10).toIso8601String());
      expect(fields[7], '60', reason: 'the slice, not the whole entry');
    });

    test('an entry that runs past the range ends at the range', () {
      final csv = export(<TimeEntry>[
        entry(
          id: 'e1',
          start: DateTime.utc(2026, 3, 10, 23),
          end: DateTime.utc(2026, 3, 11, 2),
        ),
      ]);
      final fields = fieldsOf(rowsOf(csv).single);
      expect(fields[6], DateTime.utc(2026, 3, 11).toIso8601String());
      expect(fields[7], '60');
    });

    test('an entry swallowing the whole range is clipped at both ends', () {
      final csv = export(<TimeEntry>[
        entry(
          id: 'e1',
          start: DateTime.utc(2026, 3, 9),
          end: DateTime.utc(2026, 3, 12),
        ),
      ]);
      expect(fieldsOf(rowsOf(csv).single)[7], '${24 * 60}');
    });

    test('an entry wholly outside the range does not appear', () {
      final csv = export(<TimeEntry>[
        entry(
          id: 'before',
          start: DateTime.utc(2026, 3, 9, 8),
          end: DateTime.utc(2026, 3, 9, 9),
        ),
        entry(
          id: 'after',
          start: DateTime.utc(2026, 3, 11, 8),
          end: DateTime.utc(2026, 3, 11, 9),
        ),
      ]);
      expect(rowsOf(csv), isEmpty);
    });

    test('the durations sum to the time tracked in the range', () {
      // The property that makes the file trustworthy, rather than an example
      // of it.
      final entries = <TimeEntry>[
        entry(
          id: 'e1',
          start: DateTime.utc(2026, 3, 9, 23, 30),
          end: DateTime.utc(2026, 3, 10, 0, 30),
        ),
        entry(
          id: 'e2',
          start: DateTime.utc(2026, 3, 10, 9),
          end: DateTime.utc(2026, 3, 10, 10, 45),
        ),
        entry(
          id: 'e3',
          start: DateTime.utc(2026, 3, 10, 23, 45),
          end: DateTime.utc(2026, 3, 11, 0, 15),
        ),
      ];
      final csv = export(entries);
      final summed = rowsOf(csv)
          .map((row) => int.parse(fieldsOf(row)[7]))
          .fold(0, (a, b) => a + b);
      expect(summed, csv.total.inMinutes);
      expect(csv.total, const Duration(minutes: 30 + 105 + 15));
    });
  });

  group('the running entry', () {
    test('is included with its end columns empty', () {
      final csv = export(<TimeEntry>[
        entry(id: 'r1', start: DateTime.utc(2026, 3, 10, 14)),
      ]);
      final fields = fieldsOf(rowsOf(csv).single);
      expect(fields[4], isEmpty, reason: 'end_local');
      expect(fields[6], isEmpty, reason: 'end_utc');
      expect(fields[7], '60', reason: 'measured to now');
    });

    test('is clipped like any other when the range ended before now', () {
      // Exporting last week while something runs must not credit this week's
      // hours to last week.
      final csv = buildCsv(
        entries: <TimeEntry>[
          entry(id: 'r1', start: DateTime.utc(2026, 3, 9, 23)),
        ],
        activities: activities,
        fromUtc: DateTime.utc(2026, 3, 9),
        toUtc: DateTime.utc(2026, 3, 10),
        now: now,
      );
      final fields = fieldsOf(rowsOf(csv).single);
      expect(fields[7], '60');
      expect(
        fields[6],
        DateTime.utc(2026, 3, 10).toIso8601String(),
        reason: 'clipped at the range, so this end did happen',
      );
    });
  });

  group('escaping (RFC 4180)', () {
    test('a note with a comma, a quote and a newline survives', () {
      const note = 'a,b and say "hi"\nthen stop';
      final csv = export(<TimeEntry>[
        entry(
          id: 'e1',
          start: DateTime.utc(2026, 3, 10, 9),
          end: DateTime.utc(2026, 3, 10, 10),
          note: note,
        ),
      ]);
      // The row is no longer one line, so parse the body rather than split it.
      final body = csv.text.substring(csv.text.indexOf('\r\n') + 2);
      expect(fieldsOf(body.trimRight())[2], note);
      expect(csv.text, contains('""hi""'));
    });

    test('an activity name with a comma is quoted', () {
      final csv = buildCsv(
        entries: <TimeEntry>[
          entry(
            id: 'e1',
            start: DateTime.utc(2026, 3, 10, 9),
            end: DateTime.utc(2026, 3, 10, 10),
          ),
        ],
        activities: const <String, Activity>{
          'a1': Activity(id: 'a1', name: 'Writing, specs', colorSeed: 0),
        },
        fromUtc: from,
        toUtc: to,
        now: now,
      );
      expect(csv.text, contains('"Writing, specs"'));
    });
  });

  test('rows come out oldest first, whatever order they arrived in', () {
    final csv = export(<TimeEntry>[
      entry(
        id: 'later',
        start: DateTime.utc(2026, 3, 10, 14),
        end: DateTime.utc(2026, 3, 10, 15),
      ),
      entry(
        id: 'earlier',
        start: DateTime.utc(2026, 3, 10, 9),
        end: DateTime.utc(2026, 3, 10, 10),
      ),
    ]);
    expect(rowsOf(csv).map((row) => fieldsOf(row).first), <String>[
      'earlier',
      'later',
    ]);
  });

  test('the local columns are written for a spreadsheet', () {
    final csv = export(<TimeEntry>[
      entry(
        id: 'e1',
        start: DateTime.utc(2026, 3, 10, 9, 5),
        end: DateTime.utc(2026, 3, 10, 10),
      ),
    ]);
    final local = DateTime.utc(2026, 3, 10, 9, 5).toLocal();
    final expected =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    expect(fieldsOf(rowsOf(csv).single)[3], expected);
  });

  test('the file name carries the range', () {
    expect(
      csvFileName(
        firstDay: DateTime(2026, 3, 1),
        lastDay: DateTime(2026, 3, 31),
      ),
      'time-log-2026-03-01_2026-03-31.csv',
    );
  });
}
