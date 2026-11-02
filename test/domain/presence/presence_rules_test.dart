import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/presence/active_session.dart';
import 'package:time_log/src/domain/presence/presence_rules.dart';

/// SPEC §9.9, the rules on their own.
void main() {
  final t0 = DateTime.utc(2026, 3, 10, 9);

  ActiveSession session({
    DateTime? start,
    DateTime? end,
    DateTime? lastSeen,
    SessionEndReason? reason,
  }) => ActiveSession(
    id: 's1',
    startUtc: start ?? t0,
    endUtc: end,
    lastSeenUtc: lastSeen ?? end ?? start ?? t0,
    tzName: 'Europe/Berlin',
    endReason: reason,
  );

  test('repeatedSignalChangesNothing', () {
    final open = session(lastSeen: t0.add(const Duration(minutes: 1)));
    expect(
      decide(
        open: open,
        lastClosed: null,
        signal: PresenceSignal.active(t0.add(const Duration(minutes: 2))),
      ),
      isEmpty,
    );
    expect(
      decide(
        open: null,
        lastClosed: session(end: t0),
        signal: PresenceSignal.inactive(SessionEndReason.lock, t0),
      ),
      isEmpty,
    );
  });

  test('the first active signal opens a session', () {
    final changes = decide(
      open: null,
      lastClosed: null,
      signal: PresenceSignal.active(t0),
    );
    expect(changes.single, isA<OpenSession>());
  });

  test('an inactive signal closes with its reason', () {
    final at = t0.add(const Duration(minutes: 2));
    final change =
        decide(
              open: session(lastSeen: t0.add(const Duration(minutes: 1))),
              lastClosed: null,
              signal: PresenceSignal.inactive(SessionEndReason.lock, at),
            ).single
            as CloseSession;
    expect(change.atUtc, at);
    expect(change.reason, SessionEndReason.lock);
  });

  group('short breaks', () {
    final end = t0.add(const Duration(hours: 1));

    test('shortBreakReopensSession', () {
      final at = end.add(const Duration(seconds: 59));
      final changes = decide(
        open: null,
        lastClosed: session(end: end, reason: SessionEndReason.sleep),
        signal: PresenceSignal.active(at),
      );
      expect(changes.single, isA<ReopenSession>());
    });

    test('a full minute is a break', () {
      final changes = decide(
        open: null,
        lastClosed: session(end: end, reason: SessionEndReason.sleep),
        signal: PresenceSignal.active(end.add(shortBreak)),
      );
      expect(changes.single, isA<OpenSession>());
    });

    test('turning tracking off and on is never a blink', () {
      final changes = decide(
        open: null,
        lastClosed: session(end: end, reason: SessionEndReason.off),
        signal: PresenceSignal.active(end.add(const Duration(seconds: 5))),
      );
      expect(changes.single, isA<OpenSession>());
    });
  });

  group('crash recovery', () {
    final lastSeen = t0.add(const Duration(minutes: 30));

    test('staleSessionClosesAtLastSeen', () {
      final at = lastSeen.add(const Duration(hours: 2));
      final changes = decide(
        open: session(lastSeen: lastSeen),
        lastClosed: null,
        signal: PresenceSignal.active(at),
      );
      final close = changes.first as CloseSession;
      expect(close.atUtc, lastSeen, reason: 'never a guess at now');
      expect(close.reason, SessionEndReason.lost);
      expect((changes.last as OpenSession).atUtc, at);
    });

    test('a late heartbeat within the limit is not a crash', () {
      expect(
        settle(
          open: session(lastSeen: lastSeen),
          now: lastSeen.add(staleAfter),
        ),
        isNull,
      );
    });

    test('unseenSessionIsDropped', () {
      final change = settle(
        open: session(),
        now: t0.add(const Duration(hours: 1)),
      );
      expect(change, isA<DropSession>());
    });
  });

  group('wall clock moved backwards', () {
    test('signalBeforeStartNeverGoesNegative', () {
      final lastSeen = t0.add(const Duration(minutes: 5));
      final change =
          decide(
                open: session(lastSeen: lastSeen),
                lastClosed: null,
                signal: PresenceSignal.inactive(
                  SessionEndReason.lock,
                  t0.subtract(const Duration(hours: 1)),
                ),
              ).single
              as CloseSession;
      expect(change.atUtc, lastSeen);
    });

    test('an active signal older than the last end is ignored', () {
      expect(
        decide(
          open: null,
          lastClosed: session(end: t0.add(const Duration(hours: 1))),
          signal: PresenceSignal.active(t0),
        ),
        isEmpty,
      );
    });
  });

  test('activeTotalClipsToDayWindow', () {
    final dayStart = DateTime.utc(2026, 3, 10);
    final dayEnd = DateTime.utc(2026, 3, 11);
    final total = computeActiveTotal(
      sessions: <ActiveSession>[
        session(
          start: dayStart.subtract(const Duration(hours: 1)),
          end: dayStart.add(const Duration(hours: 1)),
        ),
        session(start: dayEnd.subtract(const Duration(hours: 1))),
      ],
      from: dayStart,
      to: dayEnd,
      now: dayEnd.add(const Duration(hours: 3)),
    );
    expect(total, const Duration(hours: 2));
  });
}
