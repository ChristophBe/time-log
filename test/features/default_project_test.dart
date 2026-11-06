import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/project.dart';
import 'package:time_log/src/domain/models/time_entry.dart';
import 'package:time_log/src/features/today/start_action.dart';

/// SPEC §6.12: Start suggests the latest project.
void main() {
  const projects = <String, Project>{
    'p1': Project(id: 'p1', name: 'Client A'),
    'p2': Project(id: 'p2', name: 'Client B'),
  };
  const activities = <String, Activity>{
    'a1': Activity(id: 'a1', name: 'Email', colorSeed: 0),
    'a2': Activity(id: 'a2', name: 'Writing specs', colorSeed: 1),
  };
  final latestEntry = TimeEntry(
    id: 'e9',
    activityId: 'a2',
    startUtc: DateTime.utc(2026, 3, 10, 9),
    endUtc: null,
    tzName: 'UTC',
    projectId: 'p2',
  );

  String? defaultFor(
    String name, {
    Map<String, String?> latest = const <String, String?>{'a1': 'p1'},
    TimeEntry? entry,
    Map<String, Project> known = projects,
  }) => defaultProjectFor(
    name: name,
    activities: activities,
    latestProjectByActivity: latest,
    latestEntry: entry ?? latestEntry,
    projects: known,
  );

  test('a known activity gets the project of its own latest entry', () {
    expect(defaultFor('Email'), 'p1');
    expect(defaultFor('  email '), 'p1', reason: 'matched by nameKey');
  });

  test('a known activity whose latest entry is in none stays in none', () {
    expect(
      defaultFor('Email', latest: const <String, String?>{'a1': null}),
      isNull,
    );
  });

  test('a new name gets the latest project of all', () {
    expect(defaultFor('Code review'), 'p2');
  });

  test('an empty name gets the latest project of all', () {
    expect(defaultFor(''), 'p2');
  });

  test('a known activity with no entries falls back to the latest', () {
    expect(defaultFor('Writing specs'), 'p2');
  });

  test('a project that is gone is no project', () {
    expect(defaultFor('Email', known: const <String, Project>{}), isNull);
  });

  test('with no history at all, there is no default', () {
    expect(
      defaultProjectFor(
        name: 'Email',
        activities: activities,
        latestProjectByActivity: const <String, String?>{},
        latestEntry: null,
        projects: projects,
      ),
      isNull,
    );
  });
}
