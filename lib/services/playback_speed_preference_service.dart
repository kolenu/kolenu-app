import 'package:shared_preferences/shared_preferences.dart';

import '../data/playback_speed.dart';

const String _keyPlaybackSpeed = 'playback_speed';

/// Persists the user's preferred playback speed (slow, normal, fast).
class PlaybackSpeedPreferenceService {
  PlaybackSpeedPreferenceService._();

  static Future<PlaybackSpeed> getSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyPlaybackSpeed);
    // Default to slow (Practice speed) for first-time users
    if (name == null) return PlaybackSpeed.slow;
    final index =
        PlaybackSpeed.values.indexWhere((v) => v.name == name);
    return index >= 0
        ? PlaybackSpeed.values[index]
        : PlaybackSpeed.slow;
  }

  static Future<void> setSpeed(PlaybackSpeed speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlaybackSpeed, speed.name);
  }
}
