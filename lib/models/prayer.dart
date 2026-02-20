/// Prayer category for grouping.
String prayerCategoryDisplayName(String? category) {
  if (category == null || category.isEmpty) return 'Prayers';
  switch (category.toLowerCase()) {
    case 'synagogue':
      return 'Common Synagogue Prayers';
    case 'home_life':
      return 'Home & Life Event Prayers';
    case 'non_prayer_songs':
      return 'Non-Prayer Songs';
    case 'shabbat':
      return 'Shabbat Non-Liturgical';
    case 'camp_youth':
      return 'Camp / Youth / Group Favorites';
    case 'daily':
      return 'Daily';
    case 'hanukkah':
      return 'Hanukkah';
    case 'holidays':
      return 'Holidays';
    case 'uncategorized':
      return 'Uncategorized';
    default:
      return category;
  }
}

/// List entry from assets/audio/index.json
class PrayerListItem {
  const PrayerListItem({
    required this.id,
    required this.title,
    required this.titleHebrew,
    this.category,
    this.recordings,
    this.difficulty,
  });

  final String id;
  final String title;
  final String titleHebrew;

  /// Content filename; always "words.json" in prayer-first layout.
  String get file => 'words.json';

  /// Optional: category key for grouping (e.g. "synagogue", "home_life", "camp_youth").
  final String? category;

  /// Optional: recording IDs (audio versions) for this prayer. When set, only these are offered.
  final List<String>? recordings;

  /// Optional: difficulty level (L1–L4) for difficulty-based practice hints.
  final String? difficulty;

  static PrayerListItem fromJson(Map<String, dynamic> json) {
    final raw = json['recordings'] ?? json['versions'];
    final List<String>? list = raw is List<dynamic>
        ? raw.map((e) => e.toString()).toList()
        : null;
    return PrayerListItem(
      id: json['id'] as String,
      title: json['title'] as String,
      titleHebrew: json['titleHebrew'] as String,
      category: json['category'] as String?,
      recordings: list?.isEmpty == true ? null : list,
      difficulty: json['difficulty'] as String?,
    );
  }
}

/// One audio version for a prayer. If a prayer has multiple, user can choose.
class VersionOption {
  const VersionOption({required this.id, required this.name, this.audio});

  final String id;
  final String name;

  /// Asset filename (e.g. audio.mp3). If null, no audio for this version.
  final String? audio;

  /// Display label: folder name when id is a path (e.g. common/shema/dave_wa_1_v1 → dave_wa_1_v1), else name.
  String get displayLabel {
    if (id.contains('/')) {
      return id.split('/').last;
    }
    return name;
  }

  static VersionOption fromJson(Map<String, dynamic> json) {
    return VersionOption(
      id: json['id'] as String,
      name: json['name'] as String,
      audio: json['audio'] as String?,
    );
  }
}

/// Word with timing and optional translation (from prayer JSON words array)
class WordSegment {
  const WordSegment({
    required this.word,
    required this.start,
    required this.end,
    this.translation,
  });

  final String word;
  final double start;
  final double end;
  final String? translation;

  static WordSegment fromJson(Map<String, dynamic> json) {
    return WordSegment(
      word: json['word'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      translation: json['translation'] as String?,
    );
  }
}

/// Full prayer content from assets/prayers/{id}.json
class PrayerContent {
  const PrayerContent({
    required this.id,
    required this.title,
    required this.titleHebrew,
    this.description,
    required this.text,
    required this.sentences,
    this.sentenceEndWordIndices,
    required this.words,
    this.audio,
    this.versions,
    this.audioOffsetSeconds = 0,
    this.performerName,
    this.audioLicense,
    this.textLicense,
    this.attribution,
  });

  final String id;
  final String title;
  final String titleHebrew;
  final String? description;
  final String text;
  final List<String> sentences;

  /// 0-based index of last word of each sentence. E.g. [5, 11, 18] = sentence 0 ends at word 5.
  final List<int>? sentenceEndWordIndices;
  final List<WordSegment> words;

  /// Single audio file (legacy). Ignored if [versions] is non-null.
  final String? audio;

  /// Multiple versions; user picks one.
  final List<VersionOption>? versions;

  /// Seconds to add to playback position before matching to word timestamps (fixes sync).
  final double audioOffsetSeconds;

  /// Performer/reciter name (from doc JSON).
  final String? performerName;

  /// Audio license (e.g. CC-BY). From doc JSON.
  final String? audioLicense;

  /// Text license. From doc JSON.
  final String? textLicense;

  /// Sponsor/attribution line. From doc JSON.
  final String? attribution;

  /// Resolves which audio file to use. [selectedVersionId] if non-null and has audio;
  /// otherwise first version in [priorityOrder] that has audio; otherwise first version with audio.
  String? resolveAudioFile(
    String? selectedVersionId,
    List<String> priorityOrder,
  ) {
    if (versions != null && versions!.isNotEmpty) {
      // 1. Try selected version if specified
      if (selectedVersionId != null) {
        for (final v in versions!) {
          if (v.id == selectedVersionId &&
              v.audio != null &&
              v.audio!.isNotEmpty) {
            return v.audio;
          }
        }
      }
      // 2. Try priority order
      for (final id in priorityOrder) {
        for (final v in versions!) {
          if (v.id == id && v.audio != null && v.audio!.isNotEmpty) {
            return v.audio;
          }
        }
      }
      // 3. Fallback: any version with audio
      for (final v in versions!) {
        if (v.audio != null && v.audio!.isNotEmpty) return v.audio;
      }
      return null;
    }
    return audio;
  }

  /// Word index that ends the given sentence (0-based). Returns -1 if unknown.
  int sentenceEndWordIndex(int sentenceIndex) {
    if (sentenceEndWordIndices != null &&
        sentenceIndex >= 0 &&
        sentenceIndex < sentenceEndWordIndices!.length) {
      return sentenceEndWordIndices![sentenceIndex];
    }
    if (sentenceIndex >= 0 &&
        sentenceIndex < sentences.length &&
        words.isNotEmpty) {
      final end =
          ((sentenceIndex + 1) * words.length / sentences.length).ceil() - 1;
      return end.clamp(0, words.length - 1);
    }
    return -1;
  }

  static PrayerContent fromJson(Map<String, dynamic> json) {
    final wordsList = json['words'] as List<dynamic>? ?? [];
    final sentenceEnd = json['sentenceEndWordIndices'] as List<dynamic>?;
    return PrayerContent(
      id: json['id'] as String,
      title: json['title'] as String,
      titleHebrew: json['titleHebrew'] as String,
      description: json['description'] as String?,
      text: json['text'] as String,
      sentences:
          (json['sentences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      sentenceEndWordIndices: sentenceEnd?.map((e) => e as int).toList(),
      words: wordsList
          .map((e) => WordSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      audio: json['audio'] as String?,
      versions: ((json['versions'] ?? json['performers']) as List<dynamic>?)
          ?.map((e) => VersionOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      audioOffsetSeconds: (json['audioOffsetSeconds'] as num?)?.toDouble() ?? 0,
      performerName: json['performerName'] as String?,
      audioLicense: json['audioLicense'] as String?,
      textLicense: json['textLicense'] as String?,
      attribution: json['attribution'] as String?,
    );
  }

  /// Build PrayerContent from a words-only JSON array.
  static PrayerContent fromWordsList(
    List<dynamic> wordsList, {
    required String id,
    required String title,
    String titleHebrew = '',
  }) {
    final words = wordsList
        .map((e) => WordSegment.fromJson(e as Map<String, dynamic>))
        .toList();
    final text = words.map((w) => w.word).join(' ');
    final sentences = text.isNotEmpty ? [text] : <String>[];
    final sentenceEndWordIndices = words.isEmpty
        ? <int>[]
        : <int>[words.length - 1];
    return PrayerContent(
      id: id,
      title: title,
      titleHebrew: titleHebrew,
      description: null,
      text: text,
      sentences: sentences,
      sentenceEndWordIndices: sentenceEndWordIndices,
      words: words,
      audio: 'audio.mp3',
      versions: [VersionOption(id: id, name: title, audio: 'audio.mp3')],
      audioOffsetSeconds: 0,
      performerName: null,
      audioLicense: null,
      textLicense: null,
      attribution: null,
    );
  }
}
