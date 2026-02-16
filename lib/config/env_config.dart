/// Compile-time environment config from --dart-define.
/// String.fromEnvironment must be used in const context to work.
class EnvConfig {
  EnvConfig._();

  static const String keyName =
      String.fromEnvironment('KOLENU_KEY_NAME', defaultValue: '');
  static const String downloadKey =
      String.fromEnvironment('KOLENU_DOWNLOAD_KEY', defaultValue: '');
  static const String audioKey =
      String.fromEnvironment('KOLENU_AUDIO_KEY', defaultValue: '');
}
