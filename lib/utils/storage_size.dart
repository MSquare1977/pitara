import 'dart:io';
import '../models/document.dart';

/// Sums the on-disk size of every document's encrypted file. This is the
/// encrypted size, not the original file size — close enough for a
/// "storage used" figure, and avoids decrypting anything just to measure it.
Future<int> totalStorageBytes(List<VaultDocument> documents) async {
  var total = 0;
  for (final doc in documents) {
    final path = doc.encryptedFilePath;
    if (path == null) continue;
    try {
      total += await File(path).length();
    } catch (_) {
      // File missing/unreadable — skip it rather than failing the whole total.
    }
  }
  return total;
}

/// Formats bytes as a short human-readable string: "128 KB", "4.2 MB", "1.3 GB".
String formatStorageSize(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}
