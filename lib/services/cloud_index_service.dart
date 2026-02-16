import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/cdn_config.dart';
import '../config/env_config.dart';
import '../models/prayer.dart';
import 'prayer_service.dart';

/// Fetches and caches index.json from CDN.
/// Supports both cloud format (songs) and legacy format (prayers + versions).
class CloudIndexService {
  CloudIndexService._();

  static const _indexFilename = 'index.json';

  /// Get the Kolenu app directory.
  static Future<Directory> _getKolenuDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/kolenu');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Path to cached index.json.
  static Future<String> getCachedIndexPath() async {
    final dir = await _getKolenuDir();
    return '${dir.path}/$_indexFilename';
  }

  /// Fetch index.json from CDN and cache locally.
  /// Returns [PrayerIndex] or null if fetch fails or cloud is disabled.
  static Map<String, String> get _authHeaders =>
      {'X-App-Service-Key': EnvConfig.downloadKey};

  static Future<PrayerIndex?> fetchIndex() async {
    if (!CdnConfig.isCloudEnabled) return null;

    final url = CdnConfig.indexUrl!;
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _authHeaders,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Fetch timeout'),
      );

      if (response.statusCode != 200) {
        debugPrint('CloudIndexService: fetch failed ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        debugPrint('CloudIndexService: invalid index format');
        return null;
      }

      final index = _parseIndex(json);
      if (index == null) return null;

      final dir = await _getKolenuDir();
      final file = File('${dir.path}/$_indexFilename');
      await file.writeAsString(response.body);

      return index;
    } catch (e, st) {
      debugPrint('CloudIndexService fetch error: $e\n$st');
      return null;
    }
  }

  /// Fetch index.json from CDN. Throws on failure (server not found, timeout, etc).
  static Future<PrayerIndex> fetchIndexOrThrow() async {
    if (!CdnConfig.isCloudEnabled) {
      throw Exception('CDN not configured. Set cdnBaseUrl in lib/config/cdn_config.dart');
    }

    if (EnvConfig.keyName.isEmpty || EnvConfig.downloadKey.isEmpty) {
      throw Exception(
        'CDN keys not configured. Run with keys loaded:\n'
        '  source ../security/set_keys.sh <key_directory>\n'
        '  ./run.sh run\n'
        'Example: source ../security/set_keys.sh dummy',
      );
    }

    final url = CdnConfig.indexUrl!;
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _authHeaders,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Could not find server. Request timed out.'),
      );

      if (response.statusCode == 404) {
        throw Exception('Could not find server. Index not found (404).');
      }
      if (response.statusCode == 401) {
        throw Exception(
          'CDN returned 401 Unauthorized. The download key may be missing or wrong.\n'
          'Run: source ../security/set_keys.sh <key_directory> then ./run.sh run',
        );
      }
      if (response.statusCode != 200) {
        throw Exception('Could not find server. Server returned ${response.statusCode}.');
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw Exception('Invalid index format from server.');
      }

      final index = _parseIndex(json);
      if (index == null) {
        throw Exception('Invalid index format from server.');
      }

      final dir = await _getKolenuDir();
      final file = File('${dir.path}/$_indexFilename');
      await file.writeAsString(response.body);

      return index;
    } on http.ClientException catch (e) {
      throw Exception('Could not find server. ${e.message}');
    } on SocketException catch (e) {
      throw Exception('Could not find server. ${e.message}');
    } catch (e) {
      if (e is Exception && e.toString().contains('Could not find server')) {
        rethrow;
      }
      throw Exception('Could not find server. $e');
    }
  }

  /// Load index from local cache (for offline or fallback).
  /// Returns null if cache is empty or invalid.
  static Future<PrayerIndex?> loadFromCache() async {
    try {
      final path = await getCachedIndexPath();
      final file = File(path);
      if (!await file.exists()) return null;

      final jsonStr = await file.readAsString();
      final json = jsonDecode(jsonStr);
      if (json is! Map<String, dynamic>) return null;

      return _parseIndex(json);
    } catch (e, st) {
      debugPrint('CloudIndexService loadFromCache error: $e\n$st');
      return null;
    }
  }

  /// Try to fetch from CDN; on failure, use cached index if available.
  static Future<PrayerIndex?> fetchOrLoadCached() async {
    final index = await fetchIndex();
    if (index != null) return index;
    return loadFromCache();
  }

  /// Parse JSON into PrayerIndex. Supports:
  /// - Cloud format: { "songs": [{ "id", "title", "category", ... }] }
  /// - Legacy format: { "prayers": [...], "versions": [...] }
  static PrayerIndex? _parseIndex(Map<String, dynamic> json) {
    final songs = json['songs'] as List<dynamic>?;
    if (songs != null && songs.isNotEmpty) {
      return _parseCloudSongs(songs);
    }

    final prayers = json['prayers'] as List<dynamic>?;
    final versions = json['versions'] ?? json['performers'];
    if (prayers != null) {
      return _parseLegacyPrayers(prayers, versions);
    }

    return null;
  }

  static PrayerIndex _parseCloudSongs(List<dynamic> songs) {
    final prayerItems = <PrayerListItem>[];
    final versionOptions = <VersionOption>[];

    for (final s in songs) {
      if (s is! Map<String, dynamic>) continue;
      final songId = s['id'] as String?;
      final category = s['category'] as String? ?? 'uncategorized';
      if (songId == null || songId.isEmpty) continue;

      final folderPath = '$category/$songId';
      final title = s['title'] as String? ?? songId;
      final titleHebrew = s['titleHebrew'] as String? ?? '';

      prayerItems.add(PrayerListItem(
        id: folderPath,
        title: title,
        titleHebrew: titleHebrew,
        category: category,
        recordings: null,
        difficulty: s['difficulty'] as String?,
      ));
      versionOptions.add(VersionOption(
        id: folderPath,
        name: s['name'] as String? ?? songId,
        audio: 'audio.enc',
      ));
    }

    return PrayerIndex(prayers: prayerItems, versions: versionOptions);
  }

  static PrayerIndex _parseLegacyPrayers(
    List<dynamic> prayers,
    dynamic versions,
  ) {
    final prayerItems = prayers
        .map((e) => PrayerListItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final versionsList = versions as List<dynamic>?;
    final versionOptions = versionsList
        ?.map((e) => VersionOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return PrayerIndex(prayers: prayerItems, versions: versionOptions);
  }

  /// Clear cached index (for testing).
  static Future<void> clearCache() async {
    try {
      final path = await getCachedIndexPath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      debugPrint('CloudIndexService clearCache error: $e\n$st');
    }
  }
}
