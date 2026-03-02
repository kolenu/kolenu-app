import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/prayer.dart';
import 'song_download_service.dart';

const String _prayersAssetPath = 'assets/audio';

/// Result of loading the prayer index (list + optional recordings from folder names).
class PrayerIndex {
  const PrayerIndex({required this.prayers, this.recordings});
  final List<PrayerListItem> prayers;

  /// When set, each recording has a folder with matching .json + .mp3 per prayer.
  final List<RecordingOption>? recordings;
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
    final versionsList =
        (json['recordings'] ?? json['versions'] ?? json['performers'])
            as List<dynamic>?;
    final recordings = versionsList
        ?.map((e) => RecordingOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return PrayerIndex(prayers: prayers, recordings: recordings);
  }

  /// Load the list of prayers from index.json (convenience; use loadIndex() when you need versions).
  static Future<List<PrayerListItem>> loadPrayerList() async {
    final index = await loadIndex();
    return index.prayers;
  }

  /// Load full content for one prayer by its path (e.g. shema/ben_mitz_1_v2/words.json).
  /// When [id], [title], [titleHebrew] are provided and the file is a JSON array (words-only),
  /// builds PrayerContent from that list; otherwise expects a full PrayerContent object.
  /// When text.json exists in the same folder with "lines", merges for line-by-line display.
  static Future<PrayerContent> loadPrayerContent(
    String file, {
    String? id,
    String? title,
    String? titleHebrew,
  }) async {
    final path = '$_prayersAssetPath/$file';
    final jsonStr = await rootBundle.loadString(path);
    final decoded = jsonDecode(jsonStr);
    PrayerContent content;
    if (decoded is List<dynamic>) {
      content = PrayerContent.fromWordsList(
        decoded,
        id: id ?? 'prayer',
        title: title ?? 'Prayer',
        titleHebrew: titleHebrew ?? '',
      );
    } else if (decoded is Map<String, dynamic>) {
      content = PrayerContent.fromJson(decoded);
    } else {
      throw FormatException('Prayer JSON must be object or array', path);
    }
    // Merge title_en, title_he, and lines from text.json when available
    final dir = file.contains('/')
        ? file.substring(0, file.lastIndexOf('/'))
        : '';
    if (dir.isNotEmpty) {
      try {
        final textStr = await rootBundle.loadString(
          '$_prayersAssetPath/$dir/text.json',
        );
        final textJson = jsonDecode(textStr);
        if (textJson is Map<String, dynamic>) {
          var title = content.title;
          var titleHebrew = content.titleHebrew;
          final titleEn = (textJson['title_en'] as String?)?.trim();
          final titleHe = (textJson['title_he'] as String?)?.trim();
          if (titleEn != null && titleEn.isNotEmpty) title = titleEn;
          if (titleHe != null && titleHe.isNotEmpty) titleHebrew = titleHe;

          final linesRaw = textJson['lines'] as List<dynamic>?;
          List<String>? lines;
          if (linesRaw != null && linesRaw.isNotEmpty) {
            lines = linesRaw
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }

          if (title != content.title ||
              titleHebrew != content.titleHebrew ||
              (lines != null && lines.isNotEmpty)) {
            content = PrayerContent(
              id: content.id,
              title: title,
              titleHebrew: titleHebrew,
              description: content.description,
              text: content.text,
              lines: lines?.isNotEmpty == true ? lines : null,
              sentences: content.sentences,
              sentenceEndWordIndices: content.sentenceEndWordIndices,
              words: content.words,
              audio: content.audio,
              recordings: content.recordings,
              audioOffsetSeconds: content.audioOffsetSeconds,
              performerName: content.performerName,
              audioLicense: content.audioLicense,
              textLicense: content.textLicense,
              attribution: content.attribution,
            );
          }
        }
      } catch (_) {
        // text.json not found or invalid — ignore
      }
    }
    return content;
  }

  /// Try to load content for a prayer from a recording's folder.
  /// Uses prayer-first layout: {prayerId}/{recordingId}/{prayerFile}
  static Future<PrayerContent?> loadPrayerContentForRecording(
    String prayerId,
    String recordingId,
    String prayerFile,
  ) async {
    final file = '$prayerId/$recordingId/$prayerFile';
    try {
      return await loadPrayerContent(file);
    } catch (_) {
      return null;
    }
  }

  /// Load prayer content from a locally downloaded song folder.
  /// [songFolderId] is e.g. 'shema/ben_mitz_1_v2'.
  /// When text.json exists with "lines", merges lines for line-by-line display.
  static Future<PrayerContent> loadPrayerContentFromLocal(
    String songFolderId, {
    required String id,
    String title = '',
    String titleHebrew = '',
  }) async {
    final basePath = await SongDownloadService.getSongPath(songFolderId);
    final wordsFile = File('$basePath/words.json');
    if (!await wordsFile.exists()) {
      throw FormatException('words.json not found', basePath);
    }

    final jsonStr = await wordsFile.readAsString();
    final decoded = jsonDecode(jsonStr);

    PrayerContent content;
    if (decoded is List<dynamic>) {
      content = PrayerContent.fromWordsList(
        decoded,
        id: id,
        title: title.isNotEmpty ? title : id.replaceAll('_', ' '),
        titleHebrew: titleHebrew,
      );
    } else if (decoded is Map<String, dynamic>) {
      content = PrayerContent.fromJson(decoded);
    } else {
      throw FormatException('words.json must be array or object', basePath);
    }

    // Merge title_en, title_he, and lines from text.json when available
    final textFile = File('$basePath/text.json');
    if (await textFile.exists()) {
      try {
        final textJson = jsonDecode(await textFile.readAsString());
        if (textJson is Map<String, dynamic>) {
          var title = content.title;
          var titleHebrew = content.titleHebrew;
          final titleEn = (textJson['title_en'] as String?)?.trim();
          final titleHe = (textJson['title_he'] as String?)?.trim();
          if (titleEn != null && titleEn.isNotEmpty) title = titleEn;
          if (titleHe != null && titleHe.isNotEmpty) titleHebrew = titleHe;

          final linesRaw = textJson['lines'] as List<dynamic>?;
          List<String>? lines;
          if (linesRaw != null && linesRaw.isNotEmpty) {
            lines = linesRaw
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }

          if (title != content.title ||
              titleHebrew != content.titleHebrew ||
              (lines != null && lines.isNotEmpty)) {
            content = PrayerContent(
              id: content.id,
              title: title,
              titleHebrew: titleHebrew,
              description: content.description,
              text: content.text,
              lines: lines?.isNotEmpty == true ? lines : null,
              sentences: content.sentences,
              sentenceEndWordIndices: content.sentenceEndWordIndices,
              words: content.words,
              audio: content.audio,
              recordings: content.recordings,
              audioOffsetSeconds: content.audioOffsetSeconds,
              performerName: content.performerName,
              audioLicense: content.audioLicense,
              textLicense: content.textLicense,
              attribution: content.attribution,
            );
          }
        }
      } catch (_) {
        // Ignore text.json parse errors
      }
    }
    return content;
  }

  /// Load metadata line for a recording (performer, license, attribution).
  /// Returns null if not downloaded or content has no metadata.
  static Future<String?> loadRecordingMetadata(
    String songFolderId, {
    required String id,
    required String title,
    String titleHebrew = '',
  }) async {
    try {
      final downloaded = await SongDownloadService.isSongDownloaded(
        songFolderId,
      );
      if (!downloaded) return null;
      final content = await loadPrayerContentFromLocal(
        songFolderId,
        id: id,
        title: title,
        titleHebrew: titleHebrew,
      );
      final parts = <String>[];
      if (content.performerName != null && content.performerName!.isNotEmpty) {
        parts.add(content.performerName!);
      }
      if (content.audioLicense != null && content.audioLicense!.isNotEmpty) {
        parts.add('Audio: ${content.audioLicense!}');
      }
      if (content.textLicense != null && content.textLicense!.isNotEmpty) {
        parts.add('Text: ${content.textLicense!}');
      }
      if (content.attribution != null && content.attribution!.isNotEmpty) {
        parts.add(content.attribution!);
      }
      return parts.isEmpty ? null : parts.join(' · ');
    } catch (_) {
      return null;
    }
  }
}
