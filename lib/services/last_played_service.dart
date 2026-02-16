import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _keyLastPlayed = 'last_played_performer';

/// Stores which version was last played for each prayer.
/// Used to open the same version next time and to show a "Last played" mark in the picker.
class LastPlayedService {
  LastPlayedService._();

  static Future<String?> getLastPlayedVersion(String prayerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastPlayed);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      return map?[prayerId] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastPlayedVersion(String prayerId, String versionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastPlayed);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) map = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    map[prayerId] = versionId;
    await prefs.setString(_keyLastPlayed, jsonEncode(map));
  }
}
