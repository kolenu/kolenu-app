import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/cdn_config.dart';
import '../config/env_config.dart';
import 'cache_keys_service.dart';

/// Downloads song folders from CDN on demand. Supports atomic install.
class SongDownloadService {
  SongDownloadService._();

  static const _audioEnc = 'audio.enc';
  static const _wordsJson = 'words.json';
  static const _textJson = 'text.json';

  static Future<Directory> _getKolenuDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/kolenu');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _getSongsDir() async {
    final base = await _getKolenuDir();
    final dir = Directory('${base.path}/Songs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _getDownloadsDir() async {
    final base = await _getKolenuDir();
    final dir = Directory('${base.path}/Downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Remove cached song folders that are no longer in the index.
  /// [validRecordingIds] should be the set of all recording IDs from the current index.
  static Future<int> pruneOrphanedCache(Set<String> validRecordingIds) async {
    final songsDir = await _getSongsDir();
    if (!await songsDir.exists()) return 0;
    return _pruneOrphanedRecursive(songsDir, songsDir.path, validRecordingIds);
  }

  static Future<int> _pruneOrphanedRecursive(
    Directory dir,
    String songsRoot,
    Set<String> validRecordingIds,
  ) async {
    var removed = 0;
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final prefix = '$songsRoot${Platform.pathSeparator}';
      final relPath = entity.path.startsWith(prefix)
          ? entity.path.substring(prefix.length)
          : entity.path;
      final recordingId = relPath.replaceAll(RegExp(r'[/\\]+'), '/');
      final hasRequired =
          await File('${entity.path}/$_audioEnc').exists() &&
          await File('${entity.path}/$_wordsJson').exists() &&
          await File('${entity.path}/$_textJson').exists();
      if (hasRequired) {
        if (!validRecordingIds.contains(recordingId)) {
          await entity.delete(recursive: true);
          removed++;
        }
      } else {
        removed += await _pruneOrphanedRecursive(
          entity,
          songsRoot,
          validRecordingIds,
        );
      }
    }
    return removed;
  }

  /// Total size in bytes of all cached song files under /Songs/.
  static Future<int> getCacheSizeBytes() async {
    final songsDir = await _getSongsDir();
    if (!await songsDir.exists()) return 0;
    var total = 0;
    await for (final entity in songsDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Delete a single cached recording. [songFolderId] is e.g. 'common/shema/ben_mitz_1_v2'.
  static Future<bool> deleteRecording(String songFolderId) async {
    final folder = songFolderId.replaceAll(RegExp(r'^/+|/+$'), '');
    if (folder.isEmpty) return false;
    final songsDir = await _getSongsDir();
    final dir = Directory('${songsDir.path}/$folder');
    if (!await dir.exists()) return false;
    await dir.delete(recursive: true);
    return true;
  }

  /// Clear all downloaded songs from /Songs/. Use when switching CDN releases
  /// (e.g. dummy ↔ prod1) to avoid key mismatch.
  static Future<int> clearAllSongs() async {
    final dir = await _getSongsDir();
    var count = 0;
    if (await dir.exists()) {
      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          await entity.delete(recursive: true);
          count++;
        }
      }
    }
    return count;
  }

  /// Clean up /Downloads/ on app start (per cloud.md).
  static Future<void> cleanupDownloadsOnStart() async {
    try {
      final dir = await _getDownloadsDir();
      if (await dir.exists()) {
        for (final entity in dir.listSync()) {
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e, st) {
      debugPrint('SongDownloadService cleanupDownloadsOnStart: $e\n$st');
    }
  }

  /// Check if song folder exists and has required files.
  /// [songFolderId] is e.g. 'shem/david_dd_1_v2' or 'shema/ben_mitz_1_v2'.
  static Future<bool> isSongDownloaded(String songFolderId) async {
    // Normalize: remove leading/trailing slashes
    final folder = songFolderId.replaceAll(RegExp(r'^/+|/+$'), '');
    if (folder.isEmpty) return false;

    final songsDir = await _getSongsDir();
    final songDir = Directory('${songsDir.path}/$folder');

    if (!await songDir.exists()) return false;

    final audioFile = File('${songDir.path}/$_audioEnc');
    final wordsFile = File('${songDir.path}/$_wordsJson');
    final textFile = File('${songDir.path}/$_textJson');

    if (!await audioFile.exists() ||
        !await wordsFile.exists() ||
        !await textFile.exists()) {
      return false;
    }

    final stat = await audioFile.stat();
    return stat.size > 0;
  }

  /// Get path to song folder (for reading).
  static Future<String> getSongPath(String songFolderId) async {
    final songsDir = await _getSongsDir();
    final folder = songFolderId.replaceAll(RegExp(r'^/+|/+$'), '');
    return '${songsDir.path}/$folder';
  }

  /// Download song folder from CDN and atomically install to /Songs/.
  /// [songFolderId] is e.g. 'shem/david_dd_1_v2' (category/song_id).
  static Future<void> downloadSong(String songFolderId) async {
    if (!CdnConfig.isCloudEnabled) {
      throw Exception('CDN not configured');
    }

    final folder = songFolderId.replaceAll(RegExp(r'^/+|/+$'), '');
    if (folder.isEmpty) throw Exception('Invalid song folder id');

    final baseUrl = CdnConfig.cdnBaseUrl!;
    final audioUrl = '$baseUrl$folder/$_audioEnc';
    final wordsUrl = '$baseUrl$folder/$_wordsJson';
    final textUrl = '$baseUrl$folder/$_textJson';

    final downloadsDir = await _getDownloadsDir();
    final downloadDir = Directory('${downloadsDir.path}/$folder');
    if (await downloadDir.exists()) {
      await downloadDir.delete(recursive: true);
    }
    await downloadDir.create(recursive: true);

    try {
      await _downloadFile(audioUrl, '${downloadDir.path}/$_audioEnc');
      await _downloadFile(wordsUrl, '${downloadDir.path}/$_wordsJson');
      await _downloadFile(textUrl, '${downloadDir.path}/$_textJson');

      final audioFile = File('${downloadDir.path}/$_audioEnc');
      final wordsFile = File('${downloadDir.path}/$_wordsJson');
      final textFile = File('${downloadDir.path}/$_textJson');

      if (!await audioFile.exists() ||
          !await wordsFile.exists() ||
          !await textFile.exists()) {
        throw Exception('Download incomplete: missing required files');
      }

      final audioStat = await audioFile.stat();
      if (audioStat.size <= 0) {
        throw Exception('Download incomplete: audio.enc is empty');
      }

      await _atomicInstall(downloadDir, folder);
      await CacheKeysService.saveCacheKeys();
    } finally {
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
    }
  }

  static Map<String, String> get _authHeaders => {
    'X-App-Service-Key': EnvConfig.downloadKey,
  };

  static Future<void> _downloadFile(String url, String destPath) async {
    final response = await http
        .get(Uri.parse(url), headers: _authHeaders)
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('Download timeout'),
        );

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode} for $url');
    }

    final file = File(destPath);
    await file.writeAsBytes(response.bodyBytes);
  }

  static Future<void> _atomicInstall(
    Directory downloadDir,
    String folder,
  ) async {
    final songsDir = await _getSongsDir();
    final destDir = Directory('${songsDir.path}/$folder');
    final safeTempName = '.tmp_${folder.replaceAll('/', '_')}';
    final tempDir = Directory('${songsDir.path}/$safeTempName');

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    try {
      for (final entity in downloadDir.listSync()) {
        if (entity is File) {
          final name = entity.path.split(RegExp(r'[/\\]')).last;
          await entity.copy('${tempDir.path}/$name');
        }
      }

      final audioFile = File('${tempDir.path}/$_audioEnc');
      final wordsFile = File('${tempDir.path}/$_wordsJson');
      final textFile = File('${tempDir.path}/$_textJson');

      if (!await audioFile.exists() ||
          !await wordsFile.exists() ||
          !await textFile.exists()) {
        throw Exception('Validation failed: missing required files');
      }

      if (await destDir.exists()) {
        await destDir.delete(recursive: true);
      }
      final destParent = destDir.parent;
      if (!await destParent.exists()) {
        await destParent.create(recursive: true);
      }
      await tempDir.rename(destDir.path);
    } catch (e) {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
    }
  }
}
