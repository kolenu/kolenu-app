import 'embedded_keys.dart';

/// Compile-time environment config from --dart-define.
/// When dart-define values are empty, falls back to embedded dummy keys.
class EnvConfig {
  EnvConfig._();

  /// Release identifier (e.g. dummy, prod1). Matches keys/[release]/, cdn/source/[release]/.
  static String get release {
    const v = String.fromEnvironment('KOLENU_KEY_NAME', defaultValue: '');
    return v.isNotEmpty ? v : EmbeddedKeys.release;
  }

  static String get downloadKey {
    const v = String.fromEnvironment('KOLENU_DOWNLOAD_KEY', defaultValue: '');
    return v.isNotEmpty ? v : EmbeddedKeys.downloadKey;
  }

  static String get audioKey {
    const v = String.fromEnvironment('KOLENU_AUDIO_KEY', defaultValue: '');
    return v.isNotEmpty ? v : EmbeddedKeys.audioKey;
  }
}
