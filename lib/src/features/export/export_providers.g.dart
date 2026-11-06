// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How the file leaves the app — a download on the web, the share sheet
/// everywhere else (SPEC §8.6). A provider so a test can watch an export
/// happen without a platform channel on the other end.

@ProviderFor(exportDelivery)
final exportDeliveryProvider = ExportDeliveryProvider._();

/// How the file leaves the app — a download on the web, the share sheet
/// everywhere else (SPEC §8.6). A provider so a test can watch an export
/// happen without a platform channel on the other end.

final class ExportDeliveryProvider
    extends $FunctionalProvider<ExportDelivery, ExportDelivery, ExportDelivery>
    with $Provider<ExportDelivery> {
  /// How the file leaves the app — a download on the web, the share sheet
  /// everywhere else (SPEC §8.6). A provider so a test can watch an export
  /// happen without a platform channel on the other end.
  ExportDeliveryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exportDeliveryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exportDeliveryHash();

  @$internal
  @override
  $ProviderElement<ExportDelivery> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExportDelivery create(Ref ref) {
    return exportDelivery(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExportDelivery value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExportDelivery>(value),
    );
  }
}

String _$exportDeliveryHash() => r'053ff2e5bb7818722140f3c87c29622fbb18f2b9';

/// The extract for [range] and [project], assembled but not yet delivered.
///
/// Read once rather than watched: an export is a snapshot of a moment, and a
/// preview that shifted under the Export button while you read it would be
/// describing a different file from the one you got.

@ProviderFor(rangeExport)
final rangeExportProvider = RangeExportFamily._();

/// The extract for [range] and [project], assembled but not yet delivered.
///
/// Read once rather than watched: an export is a snapshot of a moment, and a
/// preview that shifted under the Export button while you read it would be
/// describing a different file from the one you got.

final class RangeExportProvider
    extends
        $FunctionalProvider<
          AsyncValue<CsvExport>,
          CsvExport,
          FutureOr<CsvExport>
        >
    with $FutureModifier<CsvExport>, $FutureProvider<CsvExport> {
  /// The extract for [range] and [project], assembled but not yet delivered.
  ///
  /// Read once rather than watched: an export is a snapshot of a moment, and a
  /// preview that shifted under the Export button while you read it would be
  /// describing a different file from the one you got.
  RangeExportProvider._({
    required RangeExportFamily super.from,
    required (ExportRange, ProjectFilter) super.argument,
  }) : super(
         retry: null,
         name: r'rangeExportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rangeExportHash();

  @override
  String toString() {
    return r'rangeExportProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<CsvExport> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<CsvExport> create(Ref ref) {
    final argument = this.argument as (ExportRange, ProjectFilter);
    return rangeExport(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is RangeExportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rangeExportHash() => r'd4fb79f34cbe676d9323a76b680afb2de56b2338';

/// The extract for [range] and [project], assembled but not yet delivered.
///
/// Read once rather than watched: an export is a snapshot of a moment, and a
/// preview that shifted under the Export button while you read it would be
/// describing a different file from the one you got.

final class RangeExportFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CsvExport>,
          (ExportRange, ProjectFilter)
        > {
  RangeExportFamily._()
    : super(
        retry: null,
        name: r'rangeExportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The extract for [range] and [project], assembled but not yet delivered.
  ///
  /// Read once rather than watched: an export is a snapshot of a moment, and a
  /// preview that shifted under the Export button while you read it would be
  /// describing a different file from the one you got.

  RangeExportProvider call(ExportRange range, ProjectFilter project) =>
      RangeExportProvider._(argument: (range, project), from: this);

  @override
  String toString() => r'rangeExportProvider';
}
