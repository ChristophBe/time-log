// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backupSource)
final backupSourceProvider = BackupSourceProvider._();

final class BackupSourceProvider
    extends $FunctionalProvider<BackupSource, BackupSource, BackupSource>
    with $Provider<BackupSource> {
  BackupSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupSourceHash();

  @$internal
  @override
  $ProviderElement<BackupSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackupSource create(Ref ref) {
    return backupSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupSource>(value),
    );
  }
}

String _$backupSourceHash() => r'1e687ea3a185b56f71f901d1b49517dd090cac8f';
