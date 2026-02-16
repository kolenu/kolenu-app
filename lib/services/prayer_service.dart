import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/prayer.dart';
import 'song_download_service.dart';

const String _prayersAssetPath = 'assets/audio';

/// Result of loading the prayer index (list + optional versions from folder names).
class PrayerIndex {
  const PrayerIndex({
    required this.prayers,
    this.versions,
  });
  final List<PrayerListItem> prayers;
  /// When set, each version has a folder with matching .json + .mp3 per prayer.
  final List<VersionOption>? versions;
}

/// Loads prayer list and content from assets.
class PrayerService {
  PrayerService._();

  static const _indexFile = '$_prayersAssetPath/index.json';

  /// Load prayers and optional versions from index.json.
  /// When index has "versions" (or "performers"), folder layout is used: each version = folder with prayer_id.json + prayer_id.mp3 inside.
  /// Throws [FormatException] if JSON is invalid; [FlutterError] if asset is missing.
  static Future<PrayerIndex> loadIndex() async {
    final jsonStr = await rootBundle.loadString(_indexFile);
    final json = jsonDecode(jsonStr);
    if (json is! Map<String, dynamic>) {
      throw FormatException('Index JSON must be an object', jsonStr);
    }
    final list = json['prayers'] as List<dynamic>? ?? [];
    final prayers = list
        .map((e) => PrayerListItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final versionsList = (json['versions'] ?? json['performers']) as List<dynamic>?;
    final versions = versionsList
        ?.map((e) => VersionOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return PrayerIndex(prayers: prayers, versions: versions);
  }

  /// Load the list of prayers from index.json (convenience; use loadIndex() when you need versions).
  static Future<List<PrayerListItem>> loadPrayerList() async {
    final index = await loadIndex();
    return index.prayers;
  }

  /// Load full content for one prayer by its path (e.g. shema/ben_mitz_1_v2/words.json).
  /// When [id], [title], [titleHebrew] are provided and the file is a JSON array (words-only),
  /// builds PrayerContent from that list; otherwise expects a full PrayerContent object.
  static Future<PrayerContent> loadPrayerContent(
    String file, {
    String? id,
    String? title,
    String? titleHebrew,
  }) async {
    final path = '$_prayersAssetPath/$file';
    final jsonStr = await rootBundle.loadString(path);
    final decoded = jsonDecode(jsonStr);
    if (decoded is List<dynamic>) {
      return PrayerContent.fromWordsList(
        decoded,
        id: id ?? 'prayer',
        title: title ?? 'Prayer',
        titleHebrew: titleHebrew ?? '',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Prayer JSON must be object or array', path);
    }
    return PrayerContent.fromJson(decoded);
  }

  /// Try to load content for a prayer from a version's folder.
  /// Uses prayer-first layout: {prayerId}/{versionId}/{prayerFile}
  static Future<PrayerContent?> loadPrayerContentForVersion(
    String prayerId,
    String versionId,
    String prayerFile,
  ) async {
    final file = '$prayerId/$versionId/$prayerFile';
    try {
      return await loadPrayerContent(file);
    } catch (_) {
      return null;
    }
  }

  /// Load prayer content from a locally downloaded song folder.
  /// [songFolderId] is e.g. 'shema/ben_mitz_1_v2'.
  static Future<PrayerContent> loadPrayerContentFromLocal(
    String songFolderId, {
    required String id,
    required String title,
    String titleHebrew = '',
  }) async {
    final basePath = await SongDownloadService.getSongPath(songFolderId);
    final wordsFile = File('$basePath/words.json');
    if (!await wordsFile.exists()) {
      throw FormatException('words.json not found', basePath);
    }

    final jsonStr = await wordsFile.readAsString();
    final decoded = jsonDecode(jsonStr);

    if (decoded is List<dynamic>) {
      return PrayerContent.fromWordsList(
        decoded,
        id: id,
        title: title,
        titleHebrew: titleHebrew,
      );
    }
    if (decoded is Map<String, dynamic>) {
      return PrayerContent.fromJson(decoded);
    }
    throw FormatException('words.json must be array or object', basePath);
  }
}
