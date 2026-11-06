import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/project.dart';
import '../../domain/timeline_writer.dart';
import '../today/action_feedback.dart';
import '../today/today_providers.dart';

/// The menu an entry's project is changed from (SPEC §6.12): No project, then
/// every project by name, with the current one ticked.
///
/// One menu for every place an entry's project is chosen — the start composer,
/// the running band and the entry sheet — so the choice reads the same
/// everywhere. [builder] draws whatever opens it.
class ProjectMenu extends StatelessWidget {
  const ProjectMenu({
    required this.projectId,
    required this.projects,
    required this.onChanged,
    required this.builder,
    super.key,
  });

  /// The project shown; null, or one that is not in [projects], is none.
  final String? projectId;
  final Map<String, Project> projects;
  final ValueChanged<String?> onChanged;

  /// Builds the control; call `open` to show the menu. [Project] is null for
  /// none.
  final Widget Function(
    BuildContext context,
    Project? current,
    VoidCallback open,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final current = projects[projectId];
    final sorted = projects.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return MenuAnchor(
      menuChildren: <Widget>[
        _option(
          key: const Key('project-option-none'),
          label: 'No project',
          selected: current == null,
          onPressed: () => onChanged(null),
        ),
        for (final project in sorted)
          _option(
            key: Key('project-option-${project.id}'),
            label: project.name,
            selected: project.id == current?.id,
            onPressed: () => onChanged(project.id),
          ),
      ],
      builder: (context, controller, _) => builder(
        context,
        current,
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  static Widget _option({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) => MenuItemButton(
    key: key,
    onPressed: onPressed,
    leadingIcon: selected
        ? const Icon(Icons.check_rounded, size: 18)
        : const SizedBox(width: 18),
    child: Text(label),
  );
}

/// A [ProjectMenu] opened from a compact button naming the project.
class ProjectChip extends StatelessWidget {
  const ProjectChip({
    required this.projectId,
    required this.projects,
    required this.onChanged,
    super.key,
  });

  final String? projectId;
  final Map<String, Project> projects;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => ProjectMenu(
    projectId: projectId,
    projects: projects,
    onChanged: onChanged,
    builder: (context, current, open) {
      final label = current?.name ?? 'No project';
      return Semantics(
        button: true,
        label: 'Project: $label',
        excludeSemantics: true,
        child: TextButton.icon(
          key: const Key('project-chip'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: open,
          icon: Icon(
            current == null ? Icons.folder_off_outlined : Icons.folder_outlined,
            size: 18,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded, size: 20),
            ],
          ),
        ),
      );
    },
  );
}

/// Files [entryId] under [projectId] and says so, with Undo (SPEC §6.12).
/// The one path the running band and the entry sheet both take.
Future<void> setEntryProjectWithFeedback(
  BuildContext context,
  WidgetRef ref, {
  required String entryId,
  required String? projectId,
}) async {
  final undo = await ref
      .read(timelineWriterProvider)
      .setEntryProject(entryId: entryId, projectId: projectId);
  if (undo == null || !context.mounted) return;
  final name = ref.read(projectsByIdProvider).value?[projectId]?.name;
  showUndoableFeedback(
    context,
    message: projectId == null
        ? 'Removed from project'
        : 'Moved to ${name ?? 'project'}',
    undo: undo,
  );
}
