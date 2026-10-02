// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_writer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(timelineWriter)
final timelineWriterProvider = TimelineWriterProvider._();

final class TimelineWriterProvider
    extends $FunctionalProvider<TimelineWriter, TimelineWriter, TimelineWriter>
    with $Provider<TimelineWriter> {
  TimelineWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timelineWriterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timelineWriterHash();

  @$internal
  @override
  $ProviderElement<TimelineWriter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TimelineWriter create(Ref ref) {
    return timelineWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimelineWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimelineWriter>(value),
    );
  }
}

String _$timelineWriterHash() => r'8efc4251bc54a79a10e84386d88187dd0beac416';
