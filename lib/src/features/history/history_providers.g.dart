// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How many months of history are loaded, counting the current one (SPEC §8.5).
///
/// Paging by month rather than by row: a month is the unit people think in, it
/// is bounded (a few hundred entries at most), and the range query it needs
/// already exists and is already tested. Searching and filtering then happen in
/// Dart over what is loaded, which is why there is no second SQL query here.

@ProviderFor(HistoryMonths)
final historyMonthsProvider = HistoryMonthsProvider._();

/// How many months of history are loaded, counting the current one (SPEC §8.5).
///
/// Paging by month rather than by row: a month is the unit people think in, it
/// is bounded (a few hundred entries at most), and the range query it needs
/// already exists and is already tested. Searching and filtering then happen in
/// Dart over what is loaded, which is why there is no second SQL query here.
final class HistoryMonthsProvider
    extends $NotifierProvider<HistoryMonths, int> {
  /// How many months of history are loaded, counting the current one (SPEC §8.5).
  ///
  /// Paging by month rather than by row: a month is the unit people think in, it
  /// is bounded (a few hundred entries at most), and the range query it needs
  /// already exists and is already tested. Searching and filtering then happen in
  /// Dart over what is loaded, which is why there is no second SQL query here.
  HistoryMonthsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyMonthsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyMonthsHash();

  @$internal
  @override
  HistoryMonths create() => HistoryMonths();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$historyMonthsHash() => r'1da0dd3cb62cc4c6fbcc4550d32ebb174c9afbdf';

/// How many months of history are loaded, counting the current one (SPEC §8.5).
///
/// Paging by month rather than by row: a month is the unit people think in, it
/// is bounded (a few hundred entries at most), and the range query it needs
/// already exists and is already tested. Searching and filtering then happen in
/// Dart over what is loaded, which is why there is no second SQL query here.

abstract class _$HistoryMonths extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Bumped when something asks History to start searching.
///
/// A signal rather than a shared FocusNode: SPEC §10.5 makes Cmd/Ctrl+F global,
/// so the shortcut lives in the shell — which has no business holding the
/// search field's focus node, and may not even have built History yet.

@ProviderFor(HistorySearchRequest)
final historySearchRequestProvider = HistorySearchRequestProvider._();

/// Bumped when something asks History to start searching.
///
/// A signal rather than a shared FocusNode: SPEC §10.5 makes Cmd/Ctrl+F global,
/// so the shortcut lives in the shell — which has no business holding the
/// search field's focus node, and may not even have built History yet.
final class HistorySearchRequestProvider
    extends $NotifierProvider<HistorySearchRequest, int> {
  /// Bumped when something asks History to start searching.
  ///
  /// A signal rather than a shared FocusNode: SPEC §10.5 makes Cmd/Ctrl+F global,
  /// so the shortcut lives in the shell — which has no business holding the
  /// search field's focus node, and may not even have built History yet.
  HistorySearchRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historySearchRequestProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historySearchRequestHash();

  @$internal
  @override
  HistorySearchRequest create() => HistorySearchRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$historySearchRequestHash() =>
    r'9cb06582714b06d9a2f4279e9635cc78cf755499';

/// Bumped when something asks History to start searching.
///
/// A signal rather than a shared FocusNode: SPEC §10.5 makes Cmd/Ctrl+F global,
/// so the shortcut lives in the shell — which has no business holding the
/// search field's focus node, and may not even have built History yet.

abstract class _$HistorySearchRequest extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// What is typed in the search field (SPEC §8.5).

@ProviderFor(HistoryQuery)
final historyQueryProvider = HistoryQueryProvider._();

/// What is typed in the search field (SPEC §8.5).
final class HistoryQueryProvider
    extends $NotifierProvider<HistoryQuery, String> {
  /// What is typed in the search field (SPEC §8.5).
  HistoryQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyQueryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyQueryHash();

  @$internal
  @override
  HistoryQuery create() => HistoryQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$historyQueryHash() => r'eecccd4232e5e1623b4a175d052e3b6bab438b07';

/// What is typed in the search field (SPEC §8.5).

abstract class _$HistoryQuery extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The activity the list is filtered to, or null for all of them.

@ProviderFor(HistoryActivityFilter)
final historyActivityFilterProvider = HistoryActivityFilterProvider._();

/// The activity the list is filtered to, or null for all of them.
final class HistoryActivityFilterProvider
    extends $NotifierProvider<HistoryActivityFilter, String?> {
  /// The activity the list is filtered to, or null for all of them.
  HistoryActivityFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyActivityFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyActivityFilterHash();

  @$internal
  @override
  HistoryActivityFilter create() => HistoryActivityFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$historyActivityFilterHash() =>
    r'f804fe92c2fa3c798c0a699498b733a1db812d78';

/// The activity the list is filtered to, or null for all of them.

abstract class _$HistoryActivityFilter extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The window the loaded months cover, oldest instant first.

@ProviderFor(historyWindowStart)
final historyWindowStartProvider = HistoryWindowStartProvider._();

/// The window the loaded months cover, oldest instant first.

final class HistoryWindowStartProvider
    extends $FunctionalProvider<DayWindow, DayWindow, DayWindow>
    with $Provider<DayWindow> {
  /// The window the loaded months cover, oldest instant first.
  HistoryWindowStartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyWindowStartProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyWindowStartHash();

  @$internal
  @override
  $ProviderElement<DayWindow> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DayWindow create(Ref ref) {
    return historyWindowStart(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayWindow>(value),
    );
  }
}

String _$historyWindowStartHash() =>
    r'fb640faa02dd90c8dd43bb5546e2762fa19e49a9';

/// Every live entry in the loaded months, newest first.

@ProviderFor(historyEntries)
final historyEntriesProvider = HistoryEntriesProvider._();

/// Every live entry in the loaded months, newest first.

final class HistoryEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TimeEntry>>,
          List<TimeEntry>,
          Stream<List<TimeEntry>>
        >
    with $FutureModifier<List<TimeEntry>>, $StreamProvider<List<TimeEntry>> {
  /// Every live entry in the loaded months, newest first.
  HistoryEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyEntriesHash();

  @$internal
  @override
  $StreamProviderElement<List<TimeEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TimeEntry>> create(Ref ref) {
    return historyEntries(ref);
  }
}

String _$historyEntriesHash() => r'78007d1ff55b77175ce6f27cf4290af377df69e5';

/// The entries the list should show: loaded, then filtered, then searched.
///
/// Search covers the activity's name *and* the entry's note, because the note
/// is what distinguishes two spans of the same activity (SPEC §5.1) and is
/// therefore what you remember about one.

@ProviderFor(visibleHistory)
final visibleHistoryProvider = VisibleHistoryProvider._();

/// The entries the list should show: loaded, then filtered, then searched.
///
/// Search covers the activity's name *and* the entry's note, because the note
/// is what distinguishes two spans of the same activity (SPEC §5.1) and is
/// therefore what you remember about one.

final class VisibleHistoryProvider
    extends
        $FunctionalProvider<List<TimeEntry>, List<TimeEntry>, List<TimeEntry>>
    with $Provider<List<TimeEntry>> {
  /// The entries the list should show: loaded, then filtered, then searched.
  ///
  /// Search covers the activity's name *and* the entry's note, because the note
  /// is what distinguishes two spans of the same activity (SPEC §5.1) and is
  /// therefore what you remember about one.
  VisibleHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleHistoryHash();

  @$internal
  @override
  $ProviderElement<List<TimeEntry>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<TimeEntry> create(Ref ref) {
    return visibleHistory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TimeEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TimeEntry>>(value),
    );
  }
}

String _$visibleHistoryHash() => r'98331dc8ef2b63c7931f0a7bf9d56a31edf697b8';

/// The visible entries grouped into days, newest day first.

@ProviderFor(historyDays)
final historyDaysProvider = HistoryDaysProvider._();

/// The visible entries grouped into days, newest day first.

final class HistoryDaysProvider
    extends
        $FunctionalProvider<
          List<HistoryDay>,
          List<HistoryDay>,
          List<HistoryDay>
        >
    with $Provider<List<HistoryDay>> {
  /// The visible entries grouped into days, newest day first.
  HistoryDaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyDaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyDaysHash();

  @$internal
  @override
  $ProviderElement<List<HistoryDay>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<HistoryDay> create(Ref ref) {
    return historyDays(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<HistoryDay> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<HistoryDay>>(value),
    );
  }
}

String _$historyDaysHash() => r'ce119372406f62f42a959faed51ea23879e37a43';
