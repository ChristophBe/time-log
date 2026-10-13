import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural rules from SPEC §11 that are cheap to enforce and expensive to
/// rediscover by hand.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  test('lib/ has dart files to check', () => expect(dartFiles, isNotEmpty));

  test('noDateTimeNowOutsideClock', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      if (file.path.endsWith('core/clock.dart')) continue;
      if (file.readAsStringSync().contains('DateTime.now()')) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'SPEC §11.4: take time from AppClock so the timeline stays testable',
    );
  });

  test('domainHasNoFlutterImports', () {
    final offenders = <String>[];
    // Everything under domain/ except the writer, rather than a list of
    // subdirectories: the rule is that the layer is pure, and a new folder in
    // it should inherit the rule rather than quietly escape the test.
    //
    // `timeline_writer.dart` is the one sanctioned exception. SPEC §11.3 makes
    // it the single thing that mutates the timeline, and it does that inside a
    // Drift transaction — being able to see the database is the whole point of
    // it.
    final pure = dartFiles.where(
      (f) =>
          f.path.contains('/domain/') &&
          !f.path.endsWith('domain/timeline_writer.dart'),
    );
    for (final file in pure) {
      final source = file.readAsStringSync();
      for (final banned in <String>[
        'package:flutter/',
        'package:drift/',
        'package:flutter_riverpod/',
      ]) {
        if (source.contains(banned)) offenders.add('${file.path} -> $banned');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'SPEC §11.2: domain/ is pure Dart so timeline logic is testable '
          'without a widget tree or a database',
    );
  });
}
