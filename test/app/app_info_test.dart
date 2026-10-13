import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/app/app_info.dart';

void main() {
  test('the version shown in About is the version in pubspec', () {
    // About shows a constant rather than reading the package at runtime, which
    // costs no dependency and would otherwise drift the first time the version
    // is bumped. This is what stops it.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(declared, isNotNull, reason: 'pubspec has a version');
    expect(appVersion, declared);
  });
}
