import '../timeline/clipping.dart';

/// Why an active session ended (SPEC §9.9). The name is what gets stored.
enum SessionEndReason {
  lock,
  sleep,
  switchUser,
  logout,

  /// Tracking was turned off.
  off,

  /// The app stopped hearing about the session, so this end was inferred.
  lost;

  static SessionEndReason? fromName(String? name) {
    for (final reason in values) {
      if (reason.name == name) return reason;
    }
    return null;
  }
}

/// One span during which the computer was unlocked and awake (SPEC §9.9).
///
/// Deliberately not a `TimeEntry`: it has no activity, and nothing in SPEC §4
/// applies to it.
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.startUtc,
    required this.lastSeenUtc,
    required this.tzName,
    this.endUtc,
    this.endReason,
  });

  final String id;
  final DateTime startUtc;

  /// Null while the session is open.
  final DateTime? endUtc;

  /// The latest moment the app knows this session was still going.
  final DateTime lastSeenUtc;
  final String tzName;
  final SessionEndReason? endReason;

  bool get isOpen => endUtc == null;

  DateTime endOr(DateTime now) => endUtc ?? now;

  @override
  bool operator ==(Object other) =>
      other is ActiveSession &&
      other.id == id &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc &&
      other.lastSeenUtc == lastSeenUtc &&
      other.tzName == tzName &&
      other.endReason == endReason;

  @override
  int get hashCode =>
      Object.hash(id, startUtc, endUtc, lastSeenUtc, tzName, endReason);
}

/// How much of a day [sessions] cover. An open session is measured to [now].
Duration computeActiveTotal({
  required Iterable<ActiveSession> sessions,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  var total = Duration.zero;
  for (final session in sessions) {
    final span = clipSpan(
      start: session.startUtc,
      end: session.endOr(now),
      from: from,
      to: to,
    );
    if (span != null) total += span.end.difference(span.start);
  }
  return total;
}
