import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The only file in the app that touches raw encryption. Nothing else
/// needs to know the algorithm, key handling, or IV scheme — callers just
/// hand over plain bytes and get encrypted bytes back, or vice versa.
class EncryptionService {
  static const _keyStorageKey = 'pitara_vault_key';
  final _storage = const FlutterSecureStorage();

  /// The key is generated once, then stored in the Android Keystore
  /// (via flutter_secure_storage) rather than in a plain file — this is
  /// what makes "encrypted at rest" an honest claim rather than security
  /// theatre.
  Future<enc.Key> _getOrCreateKey() async {
    final existing = await _storage.read(key: _keyStorageKey);
    if (existing != null) return enc.Key.fromBase64(existing);

    final newKey = enc.Key.fromSecureRandom(32); // AES-256
    await _storage.write(key: _keyStorageKey, value: newKey.base64);
    return newKey;
  }

  /// Returns IV + ciphertext as one byte blob (IV is the first 16 bytes),
  /// so each document only needs a single encrypted file on disk.
  Future<Uint8List> encryptBytes(Uint8List plainBytes) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    return Uint8List.fromList(iv.bytes + encrypted.bytes);
  }

  Future<Uint8List> decryptBytes(Uint8List combined) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV(combined.sublist(0, 16));
    final cipherBytes = combined.sublist(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }
}
