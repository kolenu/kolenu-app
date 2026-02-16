import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_config.dart';
import 'cloud_index_service.dart';
import 'song_download_service.dart';

/// Manages cache keys (keyName, downloadKey, audioKey) for cache invalidation.
/// When keys change, cache must be cleared.
class CacheKeysService {
  CacheKeysService._();

  static const _cacheKeysFilename = 'cache_keys.json';
  static const _prefCacheClearedMessage = 'kolenu_cache_cleared_message';

  static Future<Directory> _getKolenuDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/kolenu');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> _getCacheKeysPath() async {
    final dir = await _getKolenuDir();
    return '${dir.path}/$_cacheKeysFilename';
  }

  /// Save current keys to cache. Call when caching index.json or after download.
  static Future<void> saveCacheKeys() async {
    try {
      final path = await _getCacheKeysPath();
      final json = jsonEncode({
        'keyName': EnvConfig.keyName,
        'downloadKey': EnvConfig.downloadKey,
        'audioKey': EnvConfig.audioKey,
      });
      await File(path).writeAsString(json);
    } catch (e, st) {
      debugPrint('CacheKeysService saveCacheKeys error: $e\n$st');
    }
  }

  /// Load cached keys. Returns null if not found or invalid.
  static Future<({String keyName, String downloadKey, String audioKey})?> loadCacheKeys() async {
    try {
      final path = await _getCacheKeysPath();
      final file = File(path);
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;

      final keyName = json['keyName'] as String?;
      final downloadKey = json['downloadKey'] as String?;
      final audioKey = json['audioKey'] as String?;

      if (keyName == null || downloadKey == null || audioKey == null) return null;
      return (keyName: keyName, downloadKey: downloadKey, audioKey: audioKey);
    } catch (e, st) {
      debugPrint('CacheKeysService loadCacheKeys error: $e\n$st');
      return null;
    }
  }

  /// Check if current keys differ from cached. If so, clear all cache and return true.
  /// Call on app start. Sets SharedPreferences flag for UI to show message.
  static Future<bool> checkKeysAndClearIfChanged() async {
    final cached = await loadCacheKeys();
    if (cached == null) return false;

    final currentKeyName = EnvConfig.keyName;
    final currentDownloadKey = EnvConfig.downloadKey;
    final currentAudioKey = EnvConfig.audioKey;

    if (cached.keyName == currentKeyName &&
        cached.downloadKey == currentDownloadKey &&
        cached.audioKey == currentAudioKey) {
      return false;
    }

    await _clearAllCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefCacheClearedMessage, true);
    return true;
  }

  static Future<void> _clearAllCache() async {
    try {
      await CloudIndexService.clearCache();
      await SongDownloadService.clearAllSongs();
      await SongDownloadService.cleanupDownloadsOnStart();

      final path = await _getCacheKeysPath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      debugPrint('CacheKeysService _clearAllCache error: $e\n$st');
    }
  }

  /// Check if we should show "cache cleared" message. Clears the flag when read.
  static Future<bool> consumeCacheClearedMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_prefCacheClearedMessage) ?? false;
    if (v) await prefs.remove(_prefCacheClearedMessage);
    return v;
  }
}
