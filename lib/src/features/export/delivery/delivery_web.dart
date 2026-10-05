import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'delivery_port.dart';

/// The web: a download (SPEC §8.6).
///
/// Not `share_plus`, whose web implementation goes through the Web Share API —
/// which desktop Chrome does not offer for files, so an export there would fail
/// rather than land in the downloads folder.
ExportDelivery createDelivery() => const _DownloadDelivery();

class _DownloadDelivery implements ExportDelivery {
  const _DownloadDelivery();

  @override
  Future<void> send({
    required String fileName,
    required String text,
    required String mimeType,
  }) async {
    final blob = web.Blob(
      <JSAny>[text.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    // The browser has the bytes by now; holding the object URL open would hold
    // the whole export in memory for the life of the tab.
    web.URL.revokeObjectURL(url);
  }
}
