import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../data/hebrew_alphabet.dart';
import 'audio_decryption_service.dart';

/// Plays letter/vowel sounds from encrypted .enc assets.
class AlphabetSoundService {
  AlphabetSoundService() : _player = AudioPlayer();

  final AudioPlayer _player;

  static const String _alphabetPath = 'assets/sounds/alphabet';
  static const String _vowelsPath = 'assets/sounds/vowels';

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<void> playLetter(HebrewLetter letter) async {
    await stop();
    final key = _letterAssetKey(letter);
    await _playAsset('$_alphabetPath/$key.enc');
  }

  Future<void> playVowel(HebrewVowel vowel) async {
    await stop();
    final key = vowel.name.toLowerCase().replaceAll(' ', '_');
    await _playAsset('$_vowelsPath/$key.enc');
  }

  String _letterAssetKey(HebrewLetter letter) {
    return letter.name.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> _playAsset(String path) async {
    try {
      // Decrypt .enc file and get temporary file
      final decryptedFile = await AudioDecryptionService.decryptAudioFile(path);

      // Load decrypted audio from file
      await _player.setFilePath(decryptedFile.path);
      await _player.seek(Duration.zero);
      await _player.play();

      // Clean up temporary file after playback completes
      unawaited(
        _player.playerStateStream
            .firstWhere(
              (state) => state.processingState == ProcessingState.completed,
            )
            .then((_) {
              unawaited(
                AudioDecryptionService.deleteTemporaryFile(decryptedFile),
              );
            })
            .catchError((_) {
              // Playback was interrupted; still clean up
              unawaited(
                AudioDecryptionService.deleteTemporaryFile(decryptedFile),
              );
            }),
      );
    } catch (_) {}
  }
}
