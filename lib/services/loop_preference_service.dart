import 'package:shared_preferences/shared_preferences.dart';

const String _keyLoopOne = 'loop_one';

/// Persists whether to loop the current prayer audio (single-prayer loop).
class LoopPreferenceService {
  LoopPreferenceService._();

  static Future<bool> getLoopOne() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoopOne) ?? false;
  }

  static Future<void> setLoopOne(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoopOne, value);
  }
}
