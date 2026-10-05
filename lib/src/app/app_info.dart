/// The app's version, as shown in About (SPEC §8.6).
///
/// A constant rather than a package lookup, so that showing it costs no
/// dependency — and `test/app/app_info_test.dart` reads `pubspec.yaml` and
/// asserts they agree, so the two cannot drift apart silently.
const String appVersion = '0.1.0';
