import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'encryption_service.dart';

/// Handles where encrypted files actually live on disk. Pairs with
/// EncryptionService — this file decides storage location and filenames,
/// EncryptionService decides how bytes get scrambled.
class FileVaultService {
  final EncryptionService _encryption;

  FileVaultService(this._encryption);

  /// Encrypts [plainBytes] and writes them to the app's private documents
  /// folder (not accessible to other apps). Returns the file path to store
  /// on the VaultDocument.
  Future<String> saveEncrypted(Uint8List plainBytes, String documentId) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/vault_$documentId.enc');
    final encryptedBytes = await _encryption.encryptBytes(plainBytes);
    await file.writeAsBytes(encryptedBytes);
    return file.path;
  }

  Future<Uint8List> readDecrypted(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return _encryption.decryptBytes(bytes);
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
