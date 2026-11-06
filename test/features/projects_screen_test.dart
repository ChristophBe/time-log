import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/models/activity.dart';
import 'package:time_log/src/domain/models/project.dart';
import 'package:time_log/src/domain/timeline_writer.dart';
import 'package:time_log/src/features/entry/activity_editor.dart';
import 'package:time_log/src/features/projects/projects_screen.dart';

import '../support/pump_app.dart';

/// SPEC §8.7: the Projects destination.
void main() {
  const clientA = Project(id: 'p1', name: 'Client A');
  const clientB = Project(id: 'p2', name: 'Client B');
  final specs = const Activity(
    id: 'a1',
    name: 'Writing specs',
    colorSeed: 0,
  ).withProject('p1');
  const email = Activity(id: 'a2', name: 'Email', colorSeed: 1);

  Future<WidgetHarness> pumpScreen(
    WidgetTester tester, {
    Map<String, Project> projects = const <String, Project>{
      'p1': clientA,
      'p2': clientB,
    },
    Map<String, Activity>? activities,
    Size surfaceSize = const Size(420, 900),
  }) async {
    final h = WidgetHarness(
      activities: activities ?? <String, Activity>{'a1': specs, 'a2': email},
      projects: projects,
    );
    await h.pump(tester, const ProjectsScreen(), surfaceSize: surfaceSize);
    return h;
  }

  testWidgets('each project lists its activities, and No project the rest', (
    tester,
  ) async {
    await pumpScreen(tester);

    final a = tester.getTopLeft(find.text('Client A')).dy;
    final specsRow = tester.getTopLeft(find.text('Writing specs')).dy;
    final b = tester.getTopLeft(find.text('Client B')).dy;
    final none = tester.getTopLeft(find.text('No project')).dy;
    final emailRow = tester.getTopLeft(find.text('Email')).dy;

    expect(a < specsRow && specsRow < b, isTrue, reason: 'under Client A');
    expect(find.text('No activities'), findsOneWidget, reason: 'Client B');
    expect(none < emailRow, isTrue, reason: 'Email is in no project');
  });

  testWidgets('with nothing at all, it says what projects are for', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      projects: const <String, Project>{},
      activities: const <String, Activity>{},
    );

    expect(find.textContaining('Group activities into projects'), findsOne);
    expect(find.text('New project'), findsOneWidget);
  });

  testWidgets('New project creates it through the writer, with undo', (
    tester,
  ) async {
    final h = await pumpScreen(tester);
    when(() => h.writer.createProject(any())).thenAnswer(
      (_) async => (
        project: const Project(id: 'p3', name: 'Client C'),
        undo: UndoToken('x', () async {}),
      ),
    );

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-project-name')),
      'Client C',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    verify(() => h.writer.createProject('Client C')).called(1);
    expect(find.text('Created Client C'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('a wide window puts New project in the header', (tester) async {
    await pumpScreen(tester, surfaceSize: const Size(800, 900));

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('New project'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a project is renamed from its sheet', (tester) async {
    final h = await pumpScreen(tester);
    when(
      () => h.writer.renameProject(
        projectId: any(named: 'projectId'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) async => UndoToken('x', () async {}));

    await tester.tap(find.byTooltip('Edit Client A'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('project-name')), 'Acme');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    verify(() => h.writer.renameProject(projectId: 'p1', name: 'Acme'))
        .called(1);
    expect(find.text('Renamed to Acme'), findsOneWidget);
  });

  testWidgets('a taken name is refused in the field, not silently', (
    tester,
  ) async {
    final h = await pumpScreen(tester);
    when(
      () => h.writer.renameProject(
        projectId: any(named: 'projectId'),
        name: any(named: 'name'),
      ),
    ).thenThrow(const ProjectNameTaken(clientB));

    await tester.tap(find.byTooltip('Edit Client A'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('project-name')), 'client b');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectSheet), findsOneWidget, reason: 'still open');
    expect(find.text('Client B already exists'), findsOneWidget);
  });

  testWidgets('a project is deleted from its sheet, with undo', (tester) async {
    final h = await pumpScreen(tester);
    when(() => h.writer.deleteProject(any()))
        .thenAnswer((_) async => UndoToken('x', () async {}));

    await tester.tap(find.byTooltip('Edit Client A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete project'));
    await tester.pumpAndSettle();

    verify(() => h.writer.deleteProject('p1')).called(1);
    expect(find.text('Deleted Client A'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('tapping an activity opens its editor', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityEditor), findsOneWidget);
    expect(find.byKey(const Key('activity-project')), findsOneWidget);
  });

  testWidgets('the screen meets SPEC §10', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
