/// CDN configuration for fetching index.json and song folders.
///
/// Set [cdnBaseUrl] to your CDN base URL (e.g. https://cdn.example.com/kolenu/).
/// Must end with a slash. When null or empty, cloud fetch is disabled and
/// assets are used instead.
library;

import 'package:kolenu/config/env_config.dart';

class CdnConfig {
  CdnConfig._();

  /// CDN base URL. Set to your R2/Cloudflare CDN URL.
  /// Example: 'https://your-bucket.r2.cloudflarestorage.com/kolenu/'
  static String? get cdnBaseUrl =>
      'https://kolenu-audio.digimint.ca/${EnvConfig.release}/';

  /// Whether cloud mode is enabled (CDN URL configured).
  static bool get isCloudEnabled =>
      cdnBaseUrl != null && cdnBaseUrl!.trim().isNotEmpty;

  /// Full URL for index.json.
  static String? get indexUrl =>
      isCloudEnabled ? '${cdnBaseUrl!}index.json' : null;

  /// Full URL for broadcast messages (announcements). Same base as index.
  static String? get broadcastUrl =>
      isCloudEnabled ? '${cdnBaseUrl!}broadcast.json' : null;

  /// URL for a song folder file. [folderPath] is e.g. 'shem/david_dd_1_v2'.
  static String? urlForSongFile(String folderPath, String filename) =>
      isCloudEnabled ? '${cdnBaseUrl!}$folderPath/$filename' : null;
}
