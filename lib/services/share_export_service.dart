import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/category.dart';
import '../models/document.dart';
import 'encryption_service.dart';
import 'file_vault_service.dart';

/// Handles getting documents OUT of the vault — single-document share/export,
/// and a full encrypted-vault backup. Everything here decrypts into the
/// app's temporary cache folder only for as long as the OS share sheet is
/// open, then cleans up — decrypted copies are never left lying around.
class ShareExportService {
  final FileVaultService _fileVault;
  final EncryptionService _encryption;

  ShareExportService(this._encryption) : _fileVault = FileVaultService(_encryption);

  /// Decrypts one document's attached file and opens the OS share sheet
  /// (covers both "Share" and "Export" — on Android the share sheet itself
  /// includes "Save to Files/Drive", which is what export means in practice
  /// on this platform).
  Future<void> shareDocument(VaultDocument document) async {
    if (document.encryptedFilePath == null) return;

    final bytes = await _fileVault.readDecrypted(document.encryptedFilePath!);
    final extension = switch (document.fileType) {
      'pdf' => 'pdf',
      'file' => document.fileExtension ?? 'bin',
      _ => 'jpg',
    };
    final safeName = document.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$safeName.$extension');
    await tempFile.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(tempFile.path)], subject: document.title),
    );

    // Best-effort cleanup — the share sheet has already read the file by
    // the time this resolves.
    if (await tempFile.exists()) await tempFile.delete();
  }

  /// Decrypts one document's file and opens the device's native "save to"
  /// dialog, letting the user pick an exact folder (e.g. Downloads) to keep
  /// a copy — distinct from Share, which is for sending the file elsewhere.
  /// Returns the saved location, or null if the user cancelled.
  Future<Uri?> exportDocument(VaultDocument document) async {
    if (document.encryptedFilePath == null) return null;

    final bytes = await _fileVault.readDecrypted(document.encryptedFilePath!);
    final extension = switch (document.fileType) {
      'pdf' => 'pdf',
      'file' => document.fileExtension ?? 'bin',
      _ => 'jpg',
    };
    final safeName = document.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();

    return FilePicker.saveFile(
      fileName: '$safeName.$extension',
      bytes: bytes,
    );
  }

  /// Builds a single zip containing every document's decrypted file plus a
  /// readable manifest, then opens the share sheet so the user can save it
  /// anywhere outside the device (Drive, email, a computer, etc).
  Future<void> exportFullBackup({
    required List<VaultDocument> documents,
    required List<DocCategory> categories,
  }) async {
    final categoryNameById = {for (final c in categories) c.id: c.name};
    final archive = Archive();

    final manifestLines = <String>[
      'Pitara vault backup',
      'Exported: ${DateTime.now().toIso8601String()}',
      'Documents: ${documents.length}',
      '',
    ];

    for (final doc in documents) {
      final categoryName = categoryNameById[doc.categoryId] ?? 'Uncategorized';
      manifestLines.add('- [$categoryName] ${doc.title}'
          '${doc.subtitle != null ? ' (${doc.subtitle})' : ''}');

      if (doc.encryptedFilePath == null) continue;

      final Uint8List bytes;
      try {
        bytes = await _fileVault.readDecrypted(doc.encryptedFilePath!);
      } catch (_) {
        continue; // skip a file that fails to decrypt rather than aborting the whole backup
      }

      final extension = switch (doc.fileType) {
        'pdf' => 'pdf',
        'file' => doc.fileExtension ?? 'bin',
        _ => 'jpg',
      };
      final safeName = doc.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final entryName = '$categoryName/$safeName.$extension';
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
    }

    final manifestBytes = manifestLines.join('\n').codeUnits;
    archive.addFile(ArchiveFile('manifest.txt', manifestBytes.length, manifestBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Could not build the backup archive. Please try again.');
    }

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final zipFile = File('${tempDir.path}/pitara_backup_$stamp.zip');
    await zipFile.writeAsBytes(zipBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zipFile.path)],
        subject: 'Pitara vault backup',
        text: 'Your decrypted Pitara documents — keep this file safe, '
            "it is NOT encrypted once it's outside the app.",
      ),
    );

    if (await zipFile.exists()) await zipFile.delete();
  }
}