import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../config/env_config.dart';

/// Decrypts encrypted audio files (.enc) and provides them for playback.
/// Uses encrypt (AES-256-CBC + PKCS7) for compatibility with
/// Python PyCryptodome (encrypt_audio.py).
class AudioDecryptionService {
  AudioDecryptionService._();

  /// Decrypt an encrypted audio file from a local file path (e.g. from Songs/).
  /// The decrypted file is stored in the app's cache directory.
  /// Caller should delete the file after playback is complete.
  static Future<File> decryptFromFile(File encryptedFile) async {
    final encryptedBytes = await encryptedFile.readAsBytes();
    return _decryptBytes(encryptedBytes);
  }

  /// Decrypt an encrypted audio file from assets and return a temporary file path.
  /// The decrypted file is stored in the app's cache directory.
  /// Caller should delete the file after playback is complete.
  ///
  /// The encrypted file format is:
  /// [IV (16 bytes)][Ciphertext (variable)]
  ///
  /// Throws if decryption fails.
  static Future<File> decryptAudioFile(String assetPath) async {
    final encryptedData = await rootBundle.load(assetPath);
    final encryptedBytes = encryptedData.buffer.asUint8List();
    return _decryptBytes(encryptedBytes);
  }

  static Future<File> _decryptBytes(Uint8List encryptedBytes) async {
    final keyName = EnvConfig.keyName;
    final keyHex = EnvConfig.audioKey;

    // Keys must come from setenv.sh; exit early if not configured
    if (keyName.isEmpty || keyHex.isEmpty) {
      throw Exception(
        'Keys not loaded from setenv.sh. Run: source setenv.sh <version> (e.g. dummy) then ./run.sh run',
      );
    }
    debugPrint('Decrypting audio with key: $keyName');

    // Extract IV (first 16 bytes) and ciphertext
    if (encryptedBytes.length < 16) {
      throw Exception('Encrypted file too small (missing IV)');
    }

    final iv = encryptedBytes.sublist(0, 16);
    final ciphertext = encryptedBytes.sublist(16);

    if (ciphertext.length % 16 != 0) {
      throw Exception(
        'Audio decryption failed: ciphertext length invalid (file corrupted?). '
        'Verify the download completed.',
      );
    }

    // Get the AES key (hex string -> bytes)
    if (keyHex.length != 64) {
      throw Exception(
        'Audio key must be 64 hex chars (32 bytes). Check KOLENU_AUDIO_KEY.',
      );
    }
    final keyBytes = Uint8List.fromList([
      for (var i = 0; i < keyHex.length; i += 2)
        int.parse(keyHex.substring(i, i + 2), radix: 16),
    ]);

    try {
      final key = encrypt.Key(keyBytes);
      final ivBytes = encrypt.IV(iv);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(ciphertext),
        iv: ivBytes,
      );

      return _writeToTempCache(Uint8List.fromList(decrypted));
    } catch (e) {
      throw Exception(
        'Audio decryption failed (key: $keyName): $e. '
        'Verify source setenv.sh <version> matches the CDN version you downloaded from.',
      );
    }
  }

  static Future<File> _writeToTempCache(Uint8List decrypted) async {
    final cacheDir = await getTemporaryDirectory();
    final tempFile = File(
      '${cacheDir.path}/kolenu_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await tempFile.writeAsBytes(decrypted);
    return tempFile;
  }

  /// Clean up a temporary decrypted audio file.
  static Future<void> deleteTemporaryFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete temporary audio file: $e');
    }
  }
}
