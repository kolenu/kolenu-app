import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyLockPortrait = 'lock_portrait';

/// Persists orientation preference. When true, locks to portrait.
class OrientationPreferenceService {
  OrientationPreferenceService._();

  static Future<bool> getLockPortrait() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLockPortrait) ?? false;
  }

  static Future<void> setLockPortrait(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLockPortrait, value);
    await _applyOrientation(value);
  }

  /// Apply orientation based on preference. Call on app start.
  static Future<void> applyStoredOrientation() async {
    final lock = await getLockPortrait();
    await _applyOrientation(lock);
  }

  static Future<void> _applyOrientation(bool lockPortrait) async {
    if (lockPortrait) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }
}
