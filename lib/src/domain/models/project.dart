import 'activity.dart';

/// A named group of activities (SPEC §6.12). Identified by [nameKey], exactly
/// as an activity is, so "Client A" and "client a" are the same project.
class Project {
  const Project({required this.id, required this.name});

  final String id;
  final String name;

  String get nameKey => Activity.keyFor(name);

  static const int maxNameLength = Activity.maxNameLength;

  /// Whether [name] is acceptable as a project name (SPEC §5.1).
  static bool isValidName(String name) => Activity.isValidName(name);

  @override
  bool operator ==(Object other) =>
      other is Project && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Project($id, $name)';
}
