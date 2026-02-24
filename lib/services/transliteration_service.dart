/// Client-side Hebrew → Roman transliteration (liturgical/Israeli style).
/// Matches generate_words.py logic for consistency.
class TransliterationService {
  TransliterationService._();

  static const Map<String, String> _hebrewToRoman = {
    'א': '',
    'ב': 'v',
    'ג': 'g',
    'ד': 'd',
    'ה': 'h',
    'ו': 'v',
    'ז': 'z',
    'ח': 'ch',
    'ט': 't',
    'י': 'y',
    'כ': 'ch',
    'ך': 'ch',
    'ל': 'l',
    'מ': 'm',
    'ם': 'm',
    'נ': 'n',
    'ן': 'n',
    'ס': 's',
    'ע': '',
    'פ': 'f',
    'ף': 'f',
    'צ': 'ts',
    'ץ': 'ts',
    'ק': 'k',
    'ר': 'r',
    'ש': 'sh',
    'ת': 't',
  };

  static const Map<String, String> _nikudToRoman = {
    '\u05b0': 'a', // sheva
    '\u05b1': 'a',
    '\u05b2': 'a',
    '\u05b3': 'a',
    '\u05b4': 'i', // hiriq
    '\u05b5': 'e',
    '\u05b6': 'e',
    '\u05b7': 'a',
    '\u05b8': 'a',
    '\u05b9': 'o',
    '\u05ba': 'o',
    '\u05bb': 'u',
    '\u05bc': '', // dagesh
    '\u05c1': '', // shin dot
    '\u05c2': '', // sin dot
  };

  /// Convert Hebrew word to Roman transliteration.
  static String transliterate(String word) {
    if (word.isEmpty) return '';
    final out = <String>[];
    var i = 0;
    while (i < word.length) {
      final c = word[i];
      if (_nikudToRoman.containsKey(c)) {
        final v = _nikudToRoman[c]!;
        if (v.isNotEmpty && (out.isEmpty || !'aeiou'.contains(out.last))) {
          out.add(v);
        }
        i++;
        continue;
      }
      if (c == '\u05e9') {
        var found = false;
        for (
          var j = i + 1;
          j < word.length && _nikudToRoman.containsKey(word[j]);
          j++
        ) {
          if (word[j] == '\u05c2') {
            out.add('s');
            i = j + 1;
            found = true;
            break;
          }
          if (word[j] == '\u05c1') {
            out.add('sh');
            i = j + 1;
            found = true;
            break;
          }
        }
        if (!found) {
          out.add('sh');
          i++;
        }
        continue;
      }
      final roman = _hebrewToRoman[c];
      if (roman != null) {
        out.add(roman);
      }
      i++;
    }
    final result = out.join();
    return result.isEmpty
        ? ''
        : '${result[0].toUpperCase()}${result.substring(1)}';
  }
}
