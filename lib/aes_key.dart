// lib/aes_key.dart

// Provides the AES encryption key for the Kolenu app to decrypt audio files.
// Currently, this is a dummy key to allow the app to run without errors.
// In a real implementation, this should be replaced with a secure key management solution.

Uint8List getEncryptionKey() => Uint8List.fromList([
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
]);
