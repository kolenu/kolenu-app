/// CDN configuration for fetching index.json and song folders.
///
/// Set [cdnBaseUrl] to your CDN base URL (e.g. https://cdn.example.com/kolenu/).
/// Must end with a slash. When null or empty, cloud fetch is disabled and
/// assets are used instead.
import 'package:kolenu/config/env_config.dart';
import 'package:kolenu/config/system_config.dart';

class CdnConfig {
  CdnConfig._();

  /// CDN base URL. Set to your R2/Cloudflare CDN URL.
  /// Example: 'https://your-bucket.r2.cloudflarestorage.com/kolenu/'
  static const String? cdnBaseUrl =
      'https://kolenu-audio.digimint.ca/${EnvConfig.keyName}/';

  /// Whether cloud mode is enabled (CDN URL configured).
  static bool get isCloudEnabled =>
      cdnBaseUrl != null && cdnBaseUrl!.trim().isNotEmpty;

  /// Full URL for index.json.
  static String? get indexUrl =>
      isCloudEnabled ? '${cdnBaseUrl!}index.json' : null;

  /// URL for a song folder file. [folderPath] is e.g. 'shem/david_dd_1_v2'.
  static String? urlForSongFile(String folderPath, String filename) =>
      isCloudEnabled
          ? '${cdnBaseUrl!}$folderPath/$filename'
          : null;
}
