import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../domain/models/activity.dart';
import '../../domain/models/project.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline_writer.dart';
import 'action_feedback.dart';
import 'today_providers.dart';

/// Starts [name] now in [projectId], stopping whatever is running at the same
/// instant (SPEC §6.1).
///
/// Deliberately the whole of "start" outside the widget that triggered it, so
/// the composer, the keyboard shortcut and -- later -- a notification action or
/// a tray item all take the identical path (SPEC §13 P5).
Future<void> startActivityNamed(
  BuildContext context,
  WidgetRef ref,
  String name, {
  String? projectId,
}) async {
  // Invalid names are swallowed rather than reported: the only way to get here
  // with one is an empty field, and an error for pressing Start on nothing
  // would be noise.
  if (!Activity.isValidName(name)) return;
  final outcome = await ref
      .read(timelineWriterProvider)
      .startByName(name: name, projectId: projectId);
  if (!context.mounted) return;
  showStartFeedback(context, outcome);
}

/// The project Start uses for [name] when none was picked (SPEC §6.12): the
/// project of that activity's latest entry, or for a name with no history the
/// project of the latest entry of all.
///
/// A project that no longer exists is no project. Pure, so the rule is tested
/// without a widget.
String? defaultProjectFor({
  required String name,
  required Map<String, Activity> activities,
  required Map<String, String?> latestProjectByActivity,
  required TimeEntry? latestEntry,
  required Map<String, Project> projects,
}) {
  final key = Activity.keyFor(name);
  final String? candidate;
  final matched = key.isEmpty
      ? null
      : activities.values.where((a) => a.nameKey == key).firstOrNull;
  if (matched != null && latestProjectByActivity.containsKey(matched.id)) {
    candidate = latestProjectByActivity[matched.id];
  } else {
    candidate = latestEntry?.projectId;
  }
  return projects.containsKey(candidate) ? candidate : null;
}

/// [defaultProjectFor], read from the providers. [watch] is for a build
/// method; a callback reads.
String? defaultProjectFromRef(
  WidgetRef ref,
  String name, {
  bool watch = false,
}) {
  T get<T>(ProviderListenable<T> provider) =>
      watch ? ref.watch(provider) : ref.read(provider);
  final AsyncValue<Map<String, Activity>> activities = get(
    activitiesByIdProvider,
  );
  final AsyncValue<Map<String, String?>> latest = get(
    latestProjectByActivityProvider,
  );
  final AsyncValue<TimeEntry?> running = get(runningEntryProvider);
  final AsyncValue<TimeEntry?> lastFinished = get(lastFinishedEntryProvider);
  final AsyncValue<Map<String, Project>> projects = get(projectsByIdProvider);
  return defaultProjectFor(
    name: name,
    activities: activities.value ?? const <String, Activity>{},
    latestProjectByActivity: latest.value ?? const <String, String?>{},
    latestEntry: running.value ?? lastFinished.value,
    projects: projects.value ?? const <String, Project>{},
  );
}
