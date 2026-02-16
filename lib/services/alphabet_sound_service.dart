import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../data/hebrew_alphabet.dart';
import 'audio_decryption_service.dart';

/// Plays letter/vowel sounds: prefers MP3 from assets, falls back to Hebrew TTS.
class AlphabetSoundService {
  AlphabetSoundService() : _player = AudioPlayer();

  final AudioPlayer _player;
  final FlutterTts _tts = FlutterTts();

  static const String _alphabetPath = 'assets/sounds/alphabet';
  static const String _vowelsPath = 'assets/sounds/vowels';

  Future<void> stop() async {
    await _player.stop();
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  /// Play letter: try encrypted .enc asset first, else Hebrew TTS (speak the letter).
  Future<void> playLetter(HebrewLetter letter) async {
    await stop();
    final key = _letterAssetKey(letter);
    final ok = await _playAsset('$_alphabetPath/$key.enc');
    if (ok) return;
    await _speakHebrew(letter.hasDagesh && letter.charWithDagesh != null
        ? '${letter.charWithDagesh} ${letter.char}'
        : letter.char);
  }

  /// Play vowel: try encrypted .enc asset first, else Hebrew TTS (speak the vowel with bet).
  Future<void> playVowel(HebrewVowel vowel) async {
    await stop();
    final key = vowel.name.toLowerCase().replaceAll(' ', '_');
    final ok = await _playAsset('$_vowelsPath/$key.enc');
    if (ok) return;
    await _speakHebrew(vowel.symbolWithBet);
  }

  String _letterAssetKey(HebrewLetter letter) {
    return letter.name.toLowerCase().replaceAll(' ', '_');
  }

  Future<bool> _playAsset(String path) async {
    try {
      // Decrypt .enc file and get temporary file
      final decryptedFile = await AudioDecryptionService.decryptAudioFile(path);
      
      // Load decrypted audio from file
      await _player.setFilePath(decryptedFile.path);
      await _player.seek(Duration.zero);
      await _player.play();
      
      // Clean up temporary file after playback completes
      _player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      ).then((_) {
        AudioDecryptionService.deleteTemporaryFile(decryptedFile);
      }).catchError((_) {
        // Playback was interrupted; still clean up
        AudioDecryptionService.deleteTemporaryFile(decryptedFile);
      });
      
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _speakHebrew(String text) async {
    final result = await _tts.setLanguage('he-IL');
    // setLanguage can return bool or int depending on platform
    final ok = result == true || result == 1;
    if (!ok) return; // Only Hebrew TTS or MP3; no English fallback
    await _tts.speak(text);
  }
}
