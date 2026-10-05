import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import 'delivery_port.dart';

/// Everywhere but the web: the platform's own share sheet or save dialog
/// (SPEC §8.6).
ExportDelivery createDelivery() => const _ShareSheetDelivery();

class _ShareSheetDelivery implements ExportDelivery {
  const _ShareSheetDelivery();

  @override
  Future<void> send({
    required String fileName,
    required String text,
    required String mimeType,
  }) async {
    // From data rather than from a temporary file: there is nothing to clean up
    // afterwards, and an export that failed halfway leaves no half-written file
    // in the cache directory.
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile.fromData(utf8.encode(text), mimeType: mimeType, name: fileName),
        ],
        fileNameOverrides: <String>[fileName],
      ),
    );
  }
}
