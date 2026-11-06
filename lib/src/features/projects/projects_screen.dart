import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/palette.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/project.dart';
import '../../domain/timeline_writer.dart';
import '../today/action_feedback.dart';
import '../today/today_providers.dart';

/// Projects and the activities logged under them (SPEC §8.7).
///
/// A project belongs to entries, not activities (§6.12), so the activities
/// listed under a project are a summary of where its time went, not a
/// membership to edit: the project of an entry is chosen when it is started,
/// from the running band, or on the entry itself.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  /// Where the shell moves from a bottom bar to a rail, and so where New
  /// project moves from a FAB to the header.
  static const double _railBreakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects =
        (ref.watch(projectsByIdProvider).value ?? const <String, Project>{})
            .values
            .toList()
          ..sort((a, b) => _byName(a.name, b.name));
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final used =
        ref.watch(projectActivityIdsProvider).value ??
        const <String, Set<String>>{};

    List<Activity> membersOf(String projectId) => <Activity>[
      for (final id in used[projectId] ?? const <String>{}) ?activities[id],
    ]..sort((a, b) => _byName(a.name, b.name));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _railBreakpoint;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Projects'),
            actions: <Widget>[
              if (wide)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.lg),
                  child: FilledButton.icon(
                    onPressed: () => _create(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New project'),
                  ),
                ),
            ],
          ),
          floatingActionButton: wide
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _create(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New project'),
                ),
          body: projects.isEmpty
              ? const _Empty()
              : ListView(
                  // Room for the FAB over the last row.
                  padding: const EdgeInsets.only(bottom: 88),
                  children: <Widget>[
                    for (final project in projects) ...<Widget>[
                      _ProjectHeader(project: project),
                      ..._rows(membersOf(project.id)),
                    ],
                  ],
                ),
        );
      },
    );
  }

  static int _byName(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  static List<Widget> _rows(List<Activity> activities) => activities.isEmpty
      ? const <Widget>[_Placeholder('Nothing logged yet')]
      : <Widget>[
          for (final activity in activities)
            _ActivityRow(
              key: ValueKey<String>('project-activity-${activity.id}'),
              activity: activity,
            ),
        ];

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _askForName(context, title: 'New project');
    if (name == null || !context.mounted) return;
    final result = await ref.read(timelineWriterProvider).createProject(name);
    if (!context.mounted) return;
    showUndoableFeedback(
      context,
      message: result.undo == null
          ? '${result.project.name} already exists'
          : 'Created ${result.project.name}',
      undo: result.undo,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Insets.xl),
    child: Text(
      'Make a project to log time for it and export that time together.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.sm,
        Insets.xs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) => _GroupHeader(
    project.name,
    trailing: IconButton(
      tooltip: 'Edit ${project.name}',
      icon: const Icon(Icons.more_horiz_rounded),
      onPressed: () => showProjectSheet(context, project),
    ),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Insets.lg,
      vertical: Insets.sm,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, super.key});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final colors = ActivityPalette.forSeed(
      activity.colorSeed,
      Theme.of(context).brightness,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      leading: Container(
        width: Metrics.colorDot,
        height: Metrics.colorDot,
        decoration: BoxDecoration(color: colors.edge, shape: BoxShape.circle),
      ),
      title: Text(activity.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Rename or delete one project (SPEC §8.7).
Future<void> showProjectSheet(BuildContext context, Project project) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProjectSheet(project: project),
    );

class ProjectSheet extends ConsumerStatefulWidget {
  const ProjectSheet({required this.project, super.key});

  final Project project;

  @override
  ConsumerState<ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends ConsumerState<ProjectSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.project.name,
  );

  /// Set when the name collides with another project's (SPEC §6.12).
  String? _conflict;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name == widget.project.name) {
      Navigator.of(context).pop();
      return;
    }
    final UndoToken undo;
    try {
      undo = await ref
          .read(timelineWriterProvider)
          .renameProject(projectId: widget.project.id, name: name);
    } on ProjectNameTaken catch (taken) {
      setState(() => _conflict = '${taken.other.name} already exists');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    showUndoableFeedback(context, message: 'Renamed to $name', undo: undo);
  }

  Future<void> _delete() async {
    final undo = await ref
        .read(timelineWriterProvider)
        .deleteProject(widget.project.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showUndoableFeedback(
      context,
      message: 'Deleted ${widget.project.name}',
      undo: undo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Insets.lg,
          0,
          Insets.lg,
          Insets.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Project', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Insets.md),
            TextField(
              key: const Key('project-name'),
              controller: _name,
              maxLength: Project.maxNameLength,
              onChanged: (_) => setState(() => _conflict = null),
              onSubmitted: (_) {
                if (Project.isValidName(_name.text)) _save();
              },
              decoration: InputDecoration(
                labelText: 'Name',
                counterText: '',
                errorText: _conflict,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'Deleting a project keeps its entries; they move to No '
              'project.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Insets.sm),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete project'),
            ),
            const SizedBox(height: Insets.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: Project.isValidName(_name.text) ? _save : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a project name; null when dismissed.
Future<String?> _askForName(BuildContext context, {required String title}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NameSheet(title: title),
    );

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.title});

  final String title;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!Project.isValidName(_name.text)) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        Insets.lg,
        0,
        Insets.lg,
        Insets.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Insets.md),
          TextField(
            key: const Key('new-project-name'),
            controller: _name,
            autofocus: true,
            maxLength: Project.maxNameLength,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Name',
              counterText: '',
            ),
          ),
          const SizedBox(height: Insets.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: Project.isValidName(_name.text) ? _submit : null,
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    ),
  );
}
