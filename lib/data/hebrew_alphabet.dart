/// Hebrew alphabet and vowels (nikud) for prayer-focused learning.
/// See doc/design/hebrew_alphabet.md.
library;

/// One letter: character, name, sound for TTS.
/// When [hasDagesh] is true, the letter can have a dot (dagesh) inside;
/// [char] is without dagesh, [charWithDagesh] is with dagesh; [sound] is with dot, [soundWithoutDagesh] without.
/// Use [soundForTts] / [soundWithoutDageshForTts] when TTS mispronounces (e.g. "kh" → "ch").
class HebrewLetter {
  const HebrewLetter({
    required this.char,
    required this.name,
    required this.sound,
    this.isFinalForm = false,
    this.hasDagesh = false,
    this.charWithDagesh,
    this.soundWithoutDagesh,
    this.soundForTts,
    this.soundWithoutDageshForTts,
  });
  final String char;
  final String name;
  /// Sound when letter has dagesh (dot inside), or the only sound.
  final String sound;
  final bool isFinalForm;
  /// True for ב ג ד כ פ ת (Begadkefat): can have a dot that changes pronunciation.
  final bool hasDagesh;
  /// Letter with dagesh (e.g. בּ). Shown when [hasDagesh] is true.
  final String? charWithDagesh;
  /// Sound when letter has no dagesh (e.g. ב = "v").
  final String? soundWithoutDagesh;
  /// Spoken sound (with dagesh). If null, [sound] is used.
  final String? soundForTts;
  /// Spoken sound (without dagesh). If null, [soundWithoutDagesh] is used.
  final String? soundWithoutDageshForTts;
}

/// One vowel (nikud): name, symbol (with example letter ב for display), sound description.
class HebrewVowel {
  const HebrewVowel({
    required this.name,
    required this.symbolWithBet,
    required this.soundDesc,
    this.soundForTts,
  });
  final String name;
  /// Example: "בַּ" (Bet + Patach) for display.
  final String symbolWithBet;
  /// Full description shown in UI (e.g. "a (as in far)").
  final String soundDesc;
  /// Short sound spoken by TTS only (e.g. "a"). If null, [soundDesc] is used.
  final String? soundForTts;
}

/// All 22 letters + 5 final forms. Order: Alef through Tav, then final forms.
/// Letters ב ג ד כ פ ת have dagesh (dot inside): with dot = one sound, without = other.
const List<HebrewLetter> hebrewLetters = [
  HebrewLetter(char: 'א', name: 'Alef', sound: ''),
  HebrewLetter(char: 'ב', name: 'Bet', sound: 'b', hasDagesh: true, charWithDagesh: 'בּ', soundWithoutDagesh: 'v'),
  HebrewLetter(char: 'ג', name: 'Gimel', sound: 'g', hasDagesh: true, charWithDagesh: 'גּ', soundWithoutDagesh: 'g'),
  HebrewLetter(char: 'ד', name: 'Dalet', sound: 'd', hasDagesh: true, charWithDagesh: 'דּ', soundWithoutDagesh: 'd'),
  HebrewLetter(char: 'ה', name: 'He', sound: 'h'),
  HebrewLetter(char: 'ו', name: 'Vav', sound: 'v'),
  HebrewLetter(char: 'ז', name: 'Zayin', sound: 'z'),
  HebrewLetter(char: 'ח', name: 'Het', sound: 'kh', soundForTts: 'ch'),
  HebrewLetter(char: 'ט', name: 'Tet', sound: 't'),
  HebrewLetter(char: 'י', name: 'Yod', sound: 'y'),
  HebrewLetter(char: 'כ', name: 'Kaf', sound: 'k', hasDagesh: true, charWithDagesh: 'כּ', soundWithoutDagesh: 'kh', soundWithoutDageshForTts: 'ch'),
  HebrewLetter(char: 'ל', name: 'Lamed', sound: 'l'),
  HebrewLetter(char: 'מ', name: 'Mem', sound: 'm'),
  HebrewLetter(char: 'נ', name: 'Nun', sound: 'n'),
  HebrewLetter(char: 'ס', name: 'Samekh', sound: 's'),
  HebrewLetter(char: 'ע', name: 'Ayin', sound: ''),
  HebrewLetter(char: 'פ', name: 'Pe', sound: 'p', hasDagesh: true, charWithDagesh: 'פּ', soundWithoutDagesh: 'f'),
  HebrewLetter(char: 'צ', name: 'Tsadi', sound: 'ts', soundForTts: 'tza'),
  HebrewLetter(char: 'ק', name: 'Qof', sound: 'k'),
  HebrewLetter(char: 'ר', name: 'Resh', sound: 'r'),
  HebrewLetter(char: 'ש', name: 'Shin', sound: 'sh'),
  HebrewLetter(char: 'ת', name: 'Tav', sound: 't', hasDagesh: true, charWithDagesh: 'תּ', soundWithoutDagesh: 't'),
  // Final forms
  HebrewLetter(char: 'ך', name: 'Kaf sofit', sound: 'kh', isFinalForm: true, soundForTts: 'ch'),
  HebrewLetter(char: 'ם', name: 'Mem sofit', sound: 'm', isFinalForm: true),
  HebrewLetter(char: 'ן', name: 'Nun sofit', sound: 'n', isFinalForm: true),
  HebrewLetter(char: 'ף', name: 'Pe sofit', sound: 'f', isFinalForm: true),
  HebrewLetter(char: 'ץ', name: 'Tsadi sofit', sound: 'ts', isFinalForm: true, soundForTts: 'tza'),
];

/// Prayer-relevant vowels (nikud). Basic set per hebrew_alphabet.md.
/// soundForTts uses spellings TTS pronounces correctly (e.g. "oo" not "u" for Shuruk).
const List<HebrewVowel> hebrewVowels = [
  HebrewVowel(name: 'Patach', symbolWithBet: 'בַּ', soundDesc: 'a (as in far)', soundForTts: 'ah'),
  HebrewVowel(name: 'Kamatz', symbolWithBet: 'בָּ', soundDesc: 'a (as in far)', soundForTts: 'ah'),
  HebrewVowel(name: 'Tzere', symbolWithBet: 'בֵּ', soundDesc: 'e (as in men)', soundForTts: 'eh'),
  HebrewVowel(name: 'Segol', symbolWithBet: 'בֶּ', soundDesc: 'e (as in men)', soundForTts: 'eh'),
  HebrewVowel(name: 'Hirik', symbolWithBet: 'בִּ', soundDesc: 'i (as in seek)', soundForTts: 'ee'),
  HebrewVowel(name: 'Holam', symbolWithBet: 'בֹּ', soundDesc: 'o (as in bore)', soundForTts: 'oh'),
  HebrewVowel(name: 'Shuruk', symbolWithBet: 'וּ', soundDesc: 'u (as in cool)', soundForTts: 'ooh'),
  HebrewVowel(name: 'Kubutz', symbolWithBet: 'בֻּ', soundDesc: 'u (as in cool)', soundForTts: 'ooh'),
  HebrewVowel(name: 'Shva', symbolWithBet: 'בְ', soundDesc: 'short e or silent', soundForTts: 'silent'),
];
