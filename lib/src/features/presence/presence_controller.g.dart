// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(presenceController)
final presenceControllerProvider = PresenceControllerProvider._();

final class PresenceControllerProvider
    extends
        $FunctionalProvider<
          PresenceController,
          PresenceController,
          PresenceController
        >
    with $Provider<PresenceController> {
  PresenceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'presenceControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$presenceControllerHash();

  @$internal
  @override
  $ProviderElement<PresenceController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PresenceController create(Ref ref) {
    return presenceController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PresenceController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PresenceController>(value),
    );
  }
}

String _$presenceControllerHash() =>
    r'e252a73600e4a71df41be3a51a46bdc167e66471';
