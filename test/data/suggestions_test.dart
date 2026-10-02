import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/data/db/database.dart';
import 'package:time_log/src/data/repositories/time_entry_repository.dart';

/// SPEC §9.6: suggestions are ranked by recency x frequency with a 7-day
/// half-life, and a prefix match outranks a mere substring match.
void main() {
  final now = DateTime.utc(2026, 3, 10, 12);

  ActivityRow activity(String id, String name) => ActivityRow(
    id: id,
    name: name,
    nameKey: name.toLowerCase(),
    colorSeed: 0,
    archived: 0,
    createdAt: 0,
    updatedAt: 0,
  );

  ActivityUsageSinceResult use(ActivityRow a, Duration ago) =>
      ActivityUsageSinceResult(
        a: a,
        usedAt: now.subtract(ago).millisecondsSinceEpoch,
      );

  test('recentBeatsFrequentWithinHalfLife', () {
    final recent = activity('recent', 'Recent');
    final old = activity('old', 'Old');
    final rows = <ActivityUsageSinceResult>[
      use(recent, const Duration(hours: 1)),
      // Four uses, but all a month ago: 0.5^(30/7) is about 0.05 each.
      for (var i = 0; i < 4; i++) use(old, Duration(days: 30 + i)),
    ];

    final ranked = TimeEntryRepository.rankSuggestions(rows: rows, now: now);
    expect(ranked.first.activity.id, 'recent');
  });

  test('frequency still wins when recency is comparable', () {
    final once = activity('once', 'Once');
    final often = activity('often', 'Often');
    final rows = <ActivityUsageSinceResult>[
      use(once, const Duration(hours: 2)),
      for (var i = 0; i < 5; i++) use(often, Duration(hours: 3 + i)),
    ];

    final ranked = TimeEntryRepository.rankSuggestions(rows: rows, now: now);
    expect(ranked.first.activity.id, 'often');
  });

  test('prefixMatchOutranksSubstring', () {
    final prefix = activity('p', 'Mail triage');
    final substring = activity('s', 'Send mail');
    final rows = <ActivityUsageSinceResult>[
      use(prefix, const Duration(days: 20)),
      // Far more recent, but only a substring match.
      use(substring, const Duration(minutes: 5)),
    ];

    final ranked = TimeEntryRepository.rankSuggestions(
      rows: rows,
      now: now,
      query: 'mail',
    );
    expect(ranked.map((s) => s.activity.id), <String>['p', 's']);
    expect(ranked.first.isPrefixMatch, isTrue);
  });

  test('non-matching activities are filtered out', () {
    final rows = <ActivityUsageSinceResult>[
      use(activity('a', 'Email'), const Duration(hours: 1)),
      use(activity('b', 'Running'), const Duration(hours: 1)),
    ];
    final ranked = TimeEntryRepository.rankSuggestions(
      rows: rows,
      now: now,
      query: 'ema',
    );
    expect(ranked, hasLength(1));
    expect(ranked.single.activity.name, 'Email');
  });

  test('runningActivityIsExcluded', () {
    final rows = <ActivityUsageSinceResult>[
      use(activity('a', 'Email'), const Duration(hours: 1)),
      use(activity('b', 'Specs'), const Duration(hours: 2)),
    ];
    final ranked = TimeEntryRepository.rankSuggestions(
      rows: rows,
      now: now,
      excludeActivityId: 'a',
    );
    expect(ranked.map((s) => s.activity.id), <String>['b']);
  });

  test('the query matches case- and whitespace-insensitively', () {
    final rows = <ActivityUsageSinceResult>[
      use(activity('a', 'Deep Work'), const Duration(hours: 1)),
    ];
    expect(
      TimeEntryRepository.rankSuggestions(
        rows: rows,
        now: now,
        query: '  deep   WORK ',
      ),
      hasLength(1),
    );
  });

  test('no history yields no suggestions', () {
    expect(
      TimeEntryRepository.rankSuggestions(
        rows: const <ActivityUsageSinceResult>[],
        now: now,
      ),
      isEmpty,
    );
  });
}
