/// Embedded dummy keys for development when --dart-define is not passed.
/// Used when KOLENU_KEY_NAME, KOLENU_AUDIO_KEY, KOLENU_DOWNLOAD_KEY are empty.
class EmbeddedKeys {
  EmbeddedKeys._();

  static const String keyName = 'dummy';
  static const String audioKey =
      'c7b2b1254aa967f6ac5d2f37ebbdaf1e1f9c8b29212e756439c4f877bd5d4cfb';
  static const String downloadKey =
      'WrZSRz6uugmwHgloQkZr5CRjpLmirbGpqAde4stkhSM=';
}
