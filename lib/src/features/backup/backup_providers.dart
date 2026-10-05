import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_providers.g.dart';

/// Where a backup to import comes from.
///
/// A port rather than a direct call, for the same reason the export has one: a
/// test needs to hand the app a file without a platform file dialog in the way.
abstract interface class BackupSource {
  /// The chosen file's text, or null if the dialog was dismissed.
  Future<String?> pickBackup();
}

class _FilePickerSource implements BackupSource {
  const _FilePickerSource();

  @override
  Future<String?> pickBackup() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Choose a time-log backup',
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    final file = files.firstOrNull;
    if (file == null) return null;
    // Read as bytes rather than from a path: the web has no paths, and this
    // way there is one code path for every platform.
    return utf8.decode(await file.readAsBytes());
  }
}

@Riverpod(keepAlive: true)
BackupSource backupSource(Ref ref) => const _FilePickerSource();
