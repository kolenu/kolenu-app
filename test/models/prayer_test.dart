import 'package:flutter_test/flutter_test.dart';
import 'package:kolenu/models/prayer.dart';

void main() {
  group('PrayerListItem', () {
    test('fromJson parses required fields', () {
      final json = {
        'id': 'shema',
        'title': 'Shema',
        'titleHebrew': 'שְׁמַע יִשְׂרָאֵל',
        'difficulty': 'L1',
      };
      final item = PrayerListItem.fromJson(json);
      expect(item.id, 'shema');
      expect(item.title, 'Shema');
      expect(item.titleHebrew, 'שְׁמַע יִשְׂרָאֵל');
      expect(item.file, 'words.json'); // prayer-first layout always uses words.json
      expect(item.difficulty, 'L1');
    });
  });

  group('WordSegment', () {
    test('fromJson parses word and timestamps', () {
      final json = {
        'word': 'שְׁמַע',
        'start': 0.0,
        'end': 1.053,
        'translation': 'Hear',
      };
      final w = WordSegment.fromJson(json);
      expect(w.word, 'שְׁמַע');
      expect(w.start, 0.0);
      expect(w.end, 1.053);
      expect(w.translation, 'Hear');
    });

    test('fromJson accepts int for start/end', () {
      final json = {'word': 'אֶחָד', 'start': 5, 'end': 6};
      final w = WordSegment.fromJson(json);
      expect(w.start, 5.0);
      expect(w.end, 6.0);
      expect(w.translation, isNull);
    });
  });

  group('PrayerContent', () {
    test('fromJson parses full content with sentenceEndWordIndices', () {
      final json = {
        'id': 'shema',
        'title': 'Shema',
        'titleHebrew': 'שְׁמַע',
        'text': 'שְׁמַע יִשְׂרָאֵל',
        'sentences': ['שְׁמַע יִשְׂרָאֵל'],
        'sentenceEndWordIndices': [5, 11, 18],
        'words': [
          {'word': 'שְׁמַע', 'start': 0, 'end': 1, 'translation': 'Hear'},
        ],
        'audio': 'shema.mp3',
      };
      final content = PrayerContent.fromJson(json);
      expect(content.id, 'shema');
      expect(content.sentences.length, 1);
      expect(content.sentenceEndWordIndices, [5, 11, 18]);
      expect(content.words.length, 1);
      expect(content.words.first.word, 'שְׁמַע');
      expect(content.audio, 'shema.mp3');
    });

    test('sentenceEndWordIndex uses indices when present', () {
      final content = PrayerContent(
        id: 'x',
        title: 'X',
        titleHebrew: 'x',
        text: 'x',
        sentences: ['a', 'b', 'c'],
        sentenceEndWordIndices: [5, 11, 18],
        words: List.generate(19, (i) => WordSegment(word: '$i', start: 0, end: 1)),
      );
      expect(content.sentenceEndWordIndex(0), 5);
      expect(content.sentenceEndWordIndex(1), 11);
      expect(content.sentenceEndWordIndex(2), 18);
      expect(content.sentenceEndWordIndex(-1), -1);
      expect(content.sentenceEndWordIndex(10), -1);
    });

    test('sentenceEndWordIndex fallback when indices null', () {
      final content = PrayerContent(
        id: 'x',
        title: 'X',
        titleHebrew: 'x',
        text: 'x',
        sentences: ['a', 'b'],
        sentenceEndWordIndices: null,
        words: List.generate(10, (i) => WordSegment(word: '$i', start: 0, end: 1)),
      );
      expect(content.sentenceEndWordIndex(0), 4);
      expect(content.sentenceEndWordIndex(1), 9);
    });
  });
}
