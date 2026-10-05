import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:time_log/src/domain/backup/json_backup.dart';
import 'package:time_log/src/domain/models/app_settings.dart';

/// Runs before every test in this tree (the file name is the contract).
///
/// Loads the vendored families so that goldens render in the app's own type
/// rather than in the test font's placeholder boxes. Declaring a font in
/// `pubspec.yaml` is enough for the app and not enough for `flutter test`,
/// which starts with no font manifest at all.
///
/// This stays deterministic across machines because the fonts are files in the
/// repository, not something fetched or borrowed from the host.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Mocktail needs a fallback for every type that a test matches with `any()`.
  // Here rather than in a setUp, because a `when(...)` may be written before
  // the harness is pumped.
  registerFallbackValue(const AppSettings());
  registerFallbackValue(Duration.zero);
  registerFallbackValue(
    BackupPlan(
      file: BackupFile(
        formatVersion: backupFormatVersion,
        exportedAt: DateTime.utc(2000),
        activities: const <BackupActivity>[],
        entries: const <BackupEntry>[],
        settings: const AppSettings(),
      ),
      entriesToWrite: const <BackupEntry>[],
      activitiesToWrite: const <BackupActivity>[],
      added: 0,
      updated: 0,
      skipped: 0,
    ),
  );
  await _load('Geist', <String>[
    'assets/fonts/Geist-Regular.ttf',
    'assets/fonts/Geist-Medium.ttf',
    'assets/fonts/Geist-SemiBold.ttf',
  ]);
  await _load('GeistMono', <String>[
    'assets/fonts/GeistMono-Regular.ttf',
    'assets/fonts/GeistMono-Medium.ttf',
  ]);
  await testMain();
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
