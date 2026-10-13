import 'package:intl/intl.dart';

/// "14:32" or "2:32 PM", per the user's 12/24-hour setting.
String formatTimeOfDay(DateTime local, {required bool use24h}) =>
    (use24h ? DateFormat.Hm() : DateFormat.jm()).format(local);

/// How long something lasted: "0 min", "45 min", "1 h", "1 h 05 min".
///
/// One notation for every duration in the app, and the rule behind it is that
/// **a colon means a clock time** (SPEC §9.8). This used to switch to "1:30"
/// past the hour, which put three colon-separated numbers on a calendar block
/// where only two of them were times of day, and made the day's total read as
/// twenty past two.
///
/// The minutes are padded after an hour because the numbers are set in the
/// mono: padding is what makes a column of them line up. A whole hour drops
/// them rather than printing "2 h 00 min", which is a number nobody says.
String formatDuration(Duration d) {
  final minutes = (d.isNegative ? Duration.zero : d).inMinutes;
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes.remainder(60);
  if (m == 0) return '$h h';
  return '$h h ${m.toString().padLeft(2, '0')} min';
}

/// The ticking elapsed readout on the running band (SPEC §8.1): MM:SS under an
/// hour, H:MM:SS above it.
///
/// The one duration in the app written with colons, and the exception is
/// deliberate: this is a running counter rather than a measurement, the
/// stopwatch form is read as exactly that, and a live timer whose smallest unit
/// was a minute would look frozen for a minute at a time.
String formatElapsed(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final h = total.inHours;
  final m = total.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = total.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// How long ago something was, for a list row: "35 min", "2 h", "3 d".
///
/// The same units as [formatDuration], rounded down to one of them. Coarser on
/// purpose and not an inconsistency: this is a hint about recency in a narrow
/// trailing column, where "1 h 12 min ago" is both wider than the column wants
/// and more precision than the number deserves.
String formatAge(Duration d) {
  final minutes = (d.isNegative ? Duration.zero : d).inMinutes;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours h';
  return '${hours ~/ 24} d';
}

/// Spoken duration for screen readers (SPEC §10.4): "1 hour 30 minutes".
///
/// Deliberately coarse -- minutes, never seconds -- because this text is read
/// aloud and a seconds-precise label would change constantly.
String formatDurationVerbose(Duration d) {
  final minutes = (d.isNegative ? Duration.zero : d).inMinutes;
  final h = minutes ~/ 60;
  final m = minutes.remainder(60);
  final parts = <String>[
    if (h > 0) '$h ${h == 1 ? 'hour' : 'hours'}',
    if (m > 0 || h == 0) '$m ${m == 1 ? 'minute' : 'minutes'}',
  ];
  return parts.join(' ');
}

/// "Writing specs, 14:00 to 15:30, 1 hour 30 minutes" (SPEC §10.4).
String semanticEntryLabel({
  required String activityName,
  required DateTime startLocal,
  required DateTime? endLocal,
  required Duration duration,
  required bool use24h,
  bool isRunning = false,
}) {
  final start = formatTimeOfDay(startLocal, use24h: use24h);
  final end = endLocal == null
      ? 'now'
      : formatTimeOfDay(endLocal, use24h: use24h);
  final buffer = StringBuffer('$activityName, $start to $end, ')
    ..write(formatDurationVerbose(duration));
  if (isRunning) buffer.write(', running');
  return buffer.toString();
}
