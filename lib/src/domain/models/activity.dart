/// A named kind of work. Identified by [nameKey] so "Deep Work" and "deep work"
/// are the same activity (SPEC §5.1).
class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.colorSeed,
    this.archived = false,
  });

  final String id;
  final String name;
  final int colorSeed;
  final bool archived;

  String get nameKey => keyFor(name);

  /// Trim, collapse internal whitespace, lowercase. The matching key for
  /// "is this the same activity?".
  static String keyFor(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static const int maxNameLength = 120;

  /// Number of distinct colour slots (SPEC §9.7). The palette that renders them
  /// lives in the app layer; the count lives here because allocating a seed is
  /// part of creating an activity.
  static const int colorSeedCount = 12;

  /// The seed to give a new activity: the least-used slot, lowest index winning
  /// ties, so the first [colorSeedCount] activities each get their own hue.
  static int nextColorSeed(Iterable<int> usedSeeds) {
    final counts = List<int>.filled(colorSeedCount, 0);
    for (final seed in usedSeeds) {
      counts[seed.remainder(colorSeedCount).abs()]++;
    }
    var best = 0;
    for (var i = 1; i < colorSeedCount; i++) {
      if (counts[i] < counts[best]) best = i;
    }
    return best;
  }

  /// Whether [name] is acceptable as an activity name (SPEC §5.1).
  static bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty && trimmed.length <= maxNameLength;
  }

  Activity copyWith({String? name, int? colorSeed, bool? archived}) => Activity(
    id: id,
    name: name ?? this.name,
    colorSeed: colorSeed ?? this.colorSeed,
    archived: archived ?? this.archived,
  );

  @override
  bool operator ==(Object other) =>
      other is Activity &&
      other.id == id &&
      other.name == name &&
      other.colorSeed == colorSeed &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(id, name, colorSeed, archived);

  @override
  String toString() => 'Activity($id, $name)';
}
