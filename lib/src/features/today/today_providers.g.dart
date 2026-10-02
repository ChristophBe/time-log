// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dayWindows)
final dayWindowsProvider = DayWindowsProvider._();

final class DayWindowsProvider
    extends
        $FunctionalProvider<
          DayWindowCalculator,
          DayWindowCalculator,
          DayWindowCalculator
        >
    with $Provider<DayWindowCalculator> {
  DayWindowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayWindowsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayWindowsHash();

  @$internal
  @override
  $ProviderElement<DayWindowCalculator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DayWindowCalculator create(Ref ref) {
    return dayWindows(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayWindowCalculator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayWindowCalculator>(value),
    );
  }
}

String _$dayWindowsHash() => r'76f8e738d2dfa359305d9886b5fab12e1d9e30b2';

/// The day the calendar is showing. Defaults to today.

@ProviderFor(SelectedDay)
final selectedDayProvider = SelectedDayProvider._();

/// The day the calendar is showing. Defaults to today.
final class SelectedDayProvider
    extends $NotifierProvider<SelectedDay, DayWindow> {
  /// The day the calendar is showing. Defaults to today.
  SelectedDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedDayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedDayHash();

  @$internal
  @override
  SelectedDay create() => SelectedDay();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayWindow>(value),
    );
  }
}

String _$selectedDayHash() => r'55b5e1c92b0c448146c284a096d28dfdcec837c0';

/// The day the calendar is showing. Defaults to today.

abstract class _$SelectedDay extends $Notifier<DayWindow> {
  DayWindow build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DayWindow, DayWindow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DayWindow, DayWindow>,
              DayWindow,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(runningEntry)
final runningEntryProvider = RunningEntryProvider._();

final class RunningEntryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TimeEntry?>,
          TimeEntry?,
          Stream<TimeEntry?>
        >
    with $FutureModifier<TimeEntry?>, $StreamProvider<TimeEntry?> {
  RunningEntryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningEntryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningEntryHash();

  @$internal
  @override
  $StreamProviderElement<TimeEntry?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<TimeEntry?> create(Ref ref) {
    return runningEntry(ref);
  }
}

String _$runningEntryHash() => r'3272896be1e05e172175911184179bdac13cc1dd';

@ProviderFor(activitiesById)
final activitiesByIdProvider = ActivitiesByIdProvider._();

final class ActivitiesByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Activity>>,
          Map<String, Activity>,
          Stream<Map<String, Activity>>
        >
    with
        $FutureModifier<Map<String, Activity>>,
        $StreamProvider<Map<String, Activity>> {
  ActivitiesByIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activitiesByIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activitiesByIdHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, Activity>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, Activity>> create(Ref ref) {
    return activitiesById(ref);
  }
}

String _$activitiesByIdHash() => r'3e12151a6067017c919f9b98fd434429ace89faa';

/// Entries touching the selected day, oldest first. An entry crossing midnight
/// appears here for both days it touches (SPEC §5.3).

@ProviderFor(dayEntries)
final dayEntriesProvider = DayEntriesProvider._();

/// Entries touching the selected day, oldest first. An entry crossing midnight
/// appears here for both days it touches (SPEC §5.3).

final class DayEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TimeEntry>>,
          List<TimeEntry>,
          Stream<List<TimeEntry>>
        >
    with $FutureModifier<List<TimeEntry>>, $StreamProvider<List<TimeEntry>> {
  /// Entries touching the selected day, oldest first. An entry crossing midnight
  /// appears here for both days it touches (SPEC §5.3).
  DayEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayEntriesHash();

  @$internal
  @override
  $StreamProviderElement<List<TimeEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TimeEntry>> create(Ref ref) {
    return dayEntries(ref);
  }
}

String _$dayEntriesHash() => r'50dceccbf02d189790bd3791ade10c384d67cb9a';

/// Recomputed on the 30-second tick rather than every second, so the day view
/// does not rebuild once per second (SPEC §11.4).

@ProviderFor(dayTotals)
final dayTotalsProvider = DayTotalsProvider._();

/// Recomputed on the 30-second tick rather than every second, so the day view
/// does not rebuild once per second (SPEC §11.4).

final class DayTotalsProvider
    extends $FunctionalProvider<DayTotals, DayTotals, DayTotals>
    with $Provider<DayTotals> {
  /// Recomputed on the 30-second tick rather than every second, so the day view
  /// does not rebuild once per second (SPEC §11.4).
  DayTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayTotalsHash();

  @$internal
  @override
  $ProviderElement<DayTotals> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DayTotals create(Ref ref) {
    return dayTotals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayTotals value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayTotals>(value),
    );
  }
}

String _$dayTotalsHash() => r'3da3191ae1882d3ce6994e07d8c6175e9c647473';

@ProviderFor(activitySuggestions)
final activitySuggestionsProvider = ActivitySuggestionsFamily._();

final class ActivitySuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ActivitySuggestion>>,
          List<ActivitySuggestion>,
          Stream<List<ActivitySuggestion>>
        >
    with
        $FutureModifier<List<ActivitySuggestion>>,
        $StreamProvider<List<ActivitySuggestion>> {
  ActivitySuggestionsProvider._({
    required ActivitySuggestionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activitySuggestionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activitySuggestionsHash();

  @override
  String toString() {
    return r'activitySuggestionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ActivitySuggestion>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ActivitySuggestion>> create(Ref ref) {
    final argument = this.argument as String;
    return activitySuggestions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActivitySuggestionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activitySuggestionsHash() =>
    r'fd64e645c162178ac511f09c81077ac7a2b1ea35';

final class ActivitySuggestionsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ActivitySuggestion>>, String> {
  ActivitySuggestionsFamily._()
    : super(
        retry: null,
        name: r'activitySuggestionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ActivitySuggestionsProvider call(String query) =>
      ActivitySuggestionsProvider._(argument: query, from: this);

  @override
  String toString() => r'activitySuggestionsProvider';
}

/// The most recent finished entry, for "Resume" when nothing is running.

@ProviderFor(lastFinishedEntry)
final lastFinishedEntryProvider = LastFinishedEntryProvider._();

/// The most recent finished entry, for "Resume" when nothing is running.

final class LastFinishedEntryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TimeEntry?>,
          TimeEntry?,
          FutureOr<TimeEntry?>
        >
    with $FutureModifier<TimeEntry?>, $FutureProvider<TimeEntry?> {
  /// The most recent finished entry, for "Resume" when nothing is running.
  LastFinishedEntryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastFinishedEntryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastFinishedEntryHash();

  @$internal
  @override
  $FutureProviderElement<TimeEntry?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TimeEntry?> create(Ref ref) {
    return lastFinishedEntry(ref);
  }
}

String _$lastFinishedEntryHash() => r'7902a9a4696cf38b5093d7bb825fe6880358a4a2';
