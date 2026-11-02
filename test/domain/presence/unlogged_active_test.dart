import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/domain/presence/active_session.dart';
import 'package:time_log/src/domain/presence/unlogged_active.dart';

/// SPEC §9.9: what can be logged is what no entry covers.
void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 3, 10, hour, minute);

  ActiveSession session(DateTime start, [DateTime? end]) => ActiveSession(
    id: 's$start',
    startUtc: start,
    endUtc: end,
    lastSeenUtc: end ?? start,
    tzName: 'Europe/Berlin',
  );

  TimeEntry entry(DateTime start, [DateTime? end]) => TimeEntry(
    id: 'e$start',
    activityId: 'a1',
    startUtc: start,
    endUtc: end,
    tzName: 'Europe/Berlin',
  );

  List<({DateTime start, DateTime end})> run({
    required List<ActiveSession> sessions,
    List<TimeEntry> entries = const <TimeEntry>[],
    DateTime? now,
  }) => unloggedActive(
    sessions: sessions,
    entries: entries,
    from: DateTime.utc(2026, 3, 10),
    to: DateTime.utc(2026, 3, 11),
    now: now ?? at(18),
  );

  test('a session with no entries is offered whole', () {
    expect(run(sessions: [session(at(9), at(10))]), [
      (start: at(9), end: at(10)),
    ]);
  });

  test('unloggedActiveTimeExcludesEntries', () {
    expect(
      run(sessions: [session(at(9), at(12))], entries: [entry(at(10), at(11))]),
      [(start: at(9), end: at(10)), (start: at(11), end: at(12))],
    );
  });

  test('a fully covered session offers nothing', () {
    expect(
      run(sessions: [session(at(9), at(10))], entries: [entry(at(8), at(11))]),
      isEmpty,
    );
  });

  test('touching entries leave no sliver between them', () {
    expect(
      run(
        sessions: [session(at(9), at(11))],
        entries: [entry(at(9), at(10)), entry(at(10), at(11))],
      ),
      isEmpty,
    );
  });

  test('a span under the editing minimum is not offered', () {
    expect(
      run(
        sessions: [session(at(9), at(10))],
        entries: [entry(at(9), DateTime.utc(2026, 3, 10, 9, 59, 30))],
      ),
      isEmpty,
    );
  });

  test('an open session ends now, and a running entry covers up to now', () {
    expect(
      run(sessions: [session(at(9))], entries: [entry(at(10))], now: at(11)),
      [(start: at(9), end: at(10))],
    );
  });

  test('a session is clipped to the day', () {
    expect(run(sessions: [session(DateTime.utc(2026, 3, 9, 23), at(1))]), [
      (start: DateTime.utc(2026, 3, 10), end: at(1)),
    ]);
  });
}
