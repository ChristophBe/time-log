/// User preferences that change behaviour rather than appearance only.
class AppSettings {
  const AppSettings({
    this.snap = const Duration(minutes: 5),
    this.use24HourClock = true,
    this.themeMode = AppThemeMode.system,
    this.pixelsPerHour = 72,
    this.continueWindow = const Duration(minutes: 5),
    this.firstDayOfWeek = 0,
    this.longRun = const Duration(hours: 8),
  });

  /// Gesture edits round to this (SPEC §7.3). Zero means no snapping.
  final Duration snap;
  final bool use24HourClock;
  final AppThemeMode themeMode;

  /// Calendar zoom, clamped to [minPixelsPerHour] .. [maxPixelsPerHour].
  final double pixelsPerHour;

  /// How long after an entry ends "Continue" is still offered (SPEC §6.4).
  final Duration continueWindow;

  /// 0 follows the locale; 1..7 are `DateTime.monday`..`DateTime.sunday`.
  final int firstDayOfWeek;

  /// How long a running entry may go before the app asks whether you meant it
  /// (SPEC §8.1). Zero turns the question off.
  final Duration longRun;

  static const double minPixelsPerHour = 40;
  static const double maxPixelsPerHour = 240;
  static const List<int> snapChoicesMinutes = <int>[0, 1, 5, 15];
  static const List<int> continueChoicesMinutes = <int>[0, 5, 15, 30];
  static const List<int> longRunChoicesHours = <int>[0, 4, 8, 12];

  AppSettings copyWith({
    Duration? snap,
    bool? use24HourClock,
    AppThemeMode? themeMode,
    double? pixelsPerHour,
    Duration? continueWindow,
    int? firstDayOfWeek,
    Duration? longRun,
  }) => AppSettings(
    snap: snap ?? this.snap,
    use24HourClock: use24HourClock ?? this.use24HourClock,
    themeMode: themeMode ?? this.themeMode,
    pixelsPerHour: pixelsPerHour ?? this.pixelsPerHour,
    continueWindow: continueWindow ?? this.continueWindow,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    longRun: longRun ?? this.longRun,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.snap == snap &&
      other.use24HourClock == use24HourClock &&
      other.themeMode == themeMode &&
      other.pixelsPerHour == pixelsPerHour &&
      other.continueWindow == continueWindow &&
      other.firstDayOfWeek == firstDayOfWeek &&
      other.longRun == longRun;

  @override
  int get hashCode => Object.hash(
    snap,
    use24HourClock,
    themeMode,
    pixelsPerHour,
    continueWindow,
    firstDayOfWeek,
    longRun,
  );
}

enum AppThemeMode { system, light, dark }
