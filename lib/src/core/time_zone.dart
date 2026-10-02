import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'time_zone.g.dart';

/// Supplies the IANA zone name stored on every entry (SPEC §5.3), so a day can
/// later be reconstructed as it was lived even after moving time zones.
abstract interface class TimeZoneResolver {
  /// The device's current IANA zone, e.g. `Europe/Berlin`.
  Future<String> currentZone();
}

class PlatformTimeZoneResolver implements TimeZoneResolver {
  const PlatformTimeZoneResolver();

  @override
  Future<String> currentZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier;
    } on Object {
      // Never let an unknown zone block tracking; UTC is a usable fallback and
      // only affects how history is reinterpreted after a zone change.
      return 'UTC';
    }
  }
}

class FixedTimeZoneResolver implements TimeZoneResolver {
  const FixedTimeZoneResolver(this.zone);

  final String zone;

  @override
  Future<String> currentZone() async => zone;
}

@Riverpod(keepAlive: true)
TimeZoneResolver timeZoneResolver(Ref ref) => const PlatformTimeZoneResolver();

/// Resolved once and cached: the zone does not change mid-session often enough
/// to justify asking the platform on every write.
@Riverpod(keepAlive: true)
Future<String> currentTimeZone(Ref ref) =>
    ref.watch(timeZoneResolverProvider).currentZone();
