import 'package:shared_preferences/shared_preferences.dart';

import '../data/playback_mode.dart';

const String _keyLoopOne = 'loop_one';
const String _keyPlaybackMode = 'playback_mode';

/// Persists playback mode and legacy loop-one preference.
class LoopPreferenceService {
  LoopPreferenceService._();

  static Future<PlaybackMode> getPlaybackMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlaybackMode);
    if (raw != null) {
      for (final m in PlaybackMode.values) {
        if (m.name == raw) return m;
      }
    }
    return prefs.getBool(_keyLoopOne) == true
        ? PlaybackMode.loopOne
        : PlaybackMode.playOnce;
  }

  static Future<void> setPlaybackMode(PlaybackMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlaybackMode, mode.name);
  }

  /// Legacy: true if loop current audio.
  static Future<bool> getLoopOne() async {
    return (await getPlaybackMode()) == PlaybackMode.loopOne;
  }

  static Future<void> setLoopOne(bool value) async {
    await setPlaybackMode(
      value ? PlaybackMode.loopOne : PlaybackMode.playOnce,
    );
  }
}
