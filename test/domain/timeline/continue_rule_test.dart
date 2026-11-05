import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/app_settings.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/timeline/continue_rule.dart';

/// SPEC §6.4. The guards that decide whether Continue is offered, each on its
/// own.
void main() {
  final now = DateTime.utc(2026, 3, 10, 12);

  TimeEntry entry({
    String id = 'e1',
    String activity = 'specs',
    Duration endedAgo = const Duration(minutes: 2),
    bool running = false,
  }) => TimeEntry(
    id: id,
    activityId: activity,
    startUtc: now.subtract(const Duration(hours: 1)),
    endUtc: running ? null : now.subtract(endedAgo),
    tzName: 'UTC',
  );

  bool can(
    TimeEntry e, {
    TimeEntry? lastFinished,
    TimeEntry? running,
    Duration? window,
  }) => canContinueEntry(
    entry: e,
    lastFinished: lastFinished ?? e,
    running: running,
    now: now,
    window: window ?? const AppSettings().continueWindow,
  );

  test('the most recent entry, ended moments ago, can be continued', () {
    expect(can(entry()), isTrue);
  });

  test('an entry that ended outside the window cannot', () {
    expect(can(entry(endedAgo: const Duration(minutes: 6))), isFalse);
  });

  test('a window of zero turns it off', () {
    expect(can(entry(), window: Duration.zero), isFalse);
  });

  test('nothing may be running', () {
    expect(can(entry(), running: entry(id: 'other', running: true)), isFalse);
  });

  test('a running entry is not a candidate: it has no end to reopen', () {
    final live = entry(id: 'live', running: true);
    expect(can(live, lastFinished: live), isFalse);
  });

  test('only the most recent entry can be continued', () {
    expect(
      can(
        entry(id: 'older'),
        lastFinished: entry(id: 'newer'),
      ),
      isFalse,
      reason: 'reopening an earlier entry would overlap what came after it',
    );
  });

  test('an end in the future cannot be continued', () {
    expect(
      can(entry(endedAgo: const Duration(minutes: -1))),
      isFalse,
      reason: 'SPEC §9.2 owns the backwards-clock case',
    );
  });
}
