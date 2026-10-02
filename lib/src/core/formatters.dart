import 'package:intl/intl.dart';

/// "14:32" or "2:32 PM", per the user's 12/24-hour setting.
String formatTimeOfDay(DateTime local, {required bool use24h}) =>
    (use24h ? DateFormat.Hm() : DateFormat.jm()).format(local);

/// Compact duration for blocks and list rows: "25 min", "1:30".
String formatDurationCompact(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes.remainder(60);
  return '$h:${m.toString().padLeft(2, '0')}';
}

/// The ticking elapsed readout on the running card (SPEC §8.1): MM:SS under an
/// hour, H:MM:SS above it.
String formatElapsed(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final h = total.inHours;
  final m = total.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = total.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
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
