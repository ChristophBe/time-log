import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

/// SPEC §6.12, §8.7: the reads behind the composer's default project and the
/// Projects screen.
void main() {
  late TimelineHarness h;

  setUp(() => h = TimelineHarness());
  tearDown(() => h.close());

  Future<String> logged(String name, {String? projectId}) async {
    final start = await h.writer.startByName(name: name, projectId: projectId);
    h.clock.advance(const Duration(minutes: 30));
    await h.writer.stop();
    h.clock.advance(const Duration(minutes: 5));
    return start.entryId;
  }

  test('each activity maps to the project of its newest entry', () async {
    final a = (await h.writer.createProject('Client A')).project;
    final b = (await h.writer.createProject('Client B')).project;
    final email = await logged('Email', projectId: a.id);
    await logged('Email', projectId: b.id);
    final specs = await logged('Writing specs', projectId: a.id);
    await logged('Writing specs');

    final latest = await h.repository.watchLatestProjectByActivity().first;
    final emailId = (await h.byId(email)).activityId;
    final specsId = (await h.byId(specs)).activityId;

    expect(latest[emailId], b.id);
    expect(latest.containsKey(specsId), isTrue);
    expect(latest[specsId], isNull, reason: 'its newest entry is in none');
  });

  test('a deleted entry does not count as the newest', () async {
    final a = (await h.writer.createProject('Client A')).project;
    final b = (await h.writer.createProject('Client B')).project;
    final kept = await logged('Email', projectId: a.id);
    final deleted = await logged('Email', projectId: b.id);
    await h.writer.delete(deleted);

    final latest = await h.repository.watchLatestProjectByActivity().first;

    expect(latest[(await h.byId(kept)).activityId], a.id);
  });

  test('a project lists the activities logged under it', () async {
    final a = (await h.writer.createProject('Client A')).project;
    final email = await logged('Email', projectId: a.id);
    final specs = await logged('Writing specs', projectId: a.id);
    await logged('Reading');

    final byProject = await h.repository.watchProjectActivityIds().first;

    expect(byProject.keys, <String>[a.id]);
    expect(byProject[a.id], <String>{
      (await h.byId(email)).activityId,
      (await h.byId(specs)).activityId,
    });
  });
}
