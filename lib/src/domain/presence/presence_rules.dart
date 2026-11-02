import 'active_session.dart';

/// A break shorter than this is not a break (SPEC §9.9, rule 3).
const Duration shortBreak = Duration(seconds: 60);

/// An open session not seen for longer than this has already ended
/// (SPEC §9.9, rule 4). Three missed heartbeats, so one late timer is not a
/// crash.
const Duration staleAfter = Duration(minutes: 3);

/// What the platform says about the computer at an instant.
class PresenceSignal {
  const PresenceSignal.active(this.atUtc) : isActive = true, reason = null;

  const PresenceSignal.inactive(SessionEndReason this.reason, this.atUtc)
    : isActive = false;

  final bool isActive;
  final SessionEndReason? reason;
  final DateTime atUtc;
}

/// One thing to do to the stored sessions.
sealed class SessionChange {
  const SessionChange();
}

class OpenSession extends SessionChange {
  const OpenSession(this.atUtc);

  final DateTime atUtc;
}

class ReopenSession extends SessionChange {
  const ReopenSession(this.id, this.atUtc);

  final String id;
  final DateTime atUtc;
}

class CloseSession extends SessionChange {
  const CloseSession(this.id, this.atUtc, this.reason);

  final String id;
  final DateTime atUtc;
  final SessionEndReason reason;
}

class DropSession extends SessionChange {
  const DropSession(this.id);

  final String id;
}

/// What [signal] does, given the [open] session and the [lastClosed] one.
///
/// Idempotent by construction (rule 1): a signal that agrees with the stored
/// state changes nothing, which is what lets the heartbeat simply re-assert
/// whatever the platform currently says.
List<SessionChange> decide({
  required ActiveSession? open,
  required ActiveSession? lastClosed,
  required PresenceSignal signal,
}) {
  final at = signal.atUtc;
  if (open != null) {
    final settled = settle(open: open, now: at);
    if (settled != null) {
      return <SessionChange>[settled, if (signal.isActive) OpenSession(at)];
    }
    if (signal.isActive) return const <SessionChange>[];
    // The clock moved backwards under an open session. There is no honest way
    // to end it at `at`, so it ends at the last moment it was known to be true.
    if (!at.isAfter(open.startUtc)) {
      return <SessionChange>[_endAtLastSeen(open, signal.reason!)];
    }
    return <SessionChange>[CloseSession(open.id, at, signal.reason!)];
  }

  if (!signal.isActive) return const <SessionChange>[];
  if (lastClosed == null) return <SessionChange>[OpenSession(at)];
  final lastEnd = lastClosed.endUtc!;
  if (at.isBefore(lastEnd)) return const <SessionChange>[];
  final carriesOn =
      at.difference(lastEnd) < shortBreak &&
      // Turning tracking off and on again is a decision, not a blink.
      lastClosed.endReason != SessionEndReason.off;
  return <SessionChange>[
    carriesOn ? ReopenSession(lastClosed.id, at) : OpenSession(at),
  ];
}

/// Ends [open] if it has gone unseen for too long, or returns null if it is
/// still believable at [now] (rule 4).
SessionChange? settle({required ActiveSession open, required DateTime now}) {
  if (now.difference(open.lastSeenUtc) <= staleAfter) return null;
  return _endAtLastSeen(open, SessionEndReason.lost);
}

/// A session that was never seen after it opened has no honest end at all.
SessionChange _endAtLastSeen(ActiveSession open, SessionEndReason reason) =>
    open.lastSeenUtc.isAfter(open.startUtc)
    ? CloseSession(open.id, open.lastSeenUtc, reason)
    : DropSession(open.id);
