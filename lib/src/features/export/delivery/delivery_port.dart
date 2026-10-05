/// How a finished export leaves the app.
///
/// An interface because the two mechanisms are genuinely different — a browser
/// downloads, everything else shares — and because a test needs to watch an
/// export happen without a platform channel on the other end.
abstract interface class ExportDelivery {
  Future<void> send({
    required String fileName,
    required String text,
    required String mimeType,
  });
}
