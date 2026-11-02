// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_port.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(presencePort)
final presencePortProvider = PresencePortProvider._();

final class PresencePortProvider
    extends $FunctionalProvider<PresencePort, PresencePort, PresencePort>
    with $Provider<PresencePort> {
  PresencePortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'presencePortProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$presencePortHash();

  @$internal
  @override
  $ProviderElement<PresencePort> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PresencePort create(Ref ref) {
    return presencePort(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PresencePort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PresencePort>(value),
    );
  }
}

String _$presencePortHash() => r'71b5c682612a2ddf010bd9d6365fdf74fd1da72a';
