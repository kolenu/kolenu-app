import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _keyPlaylist = 'default_playlist';
const String _keyShuffle = 'playlist_shuffle';

/// Ordered list of prayer IDs for the default playlist.
/// Used when user taps "Play playlist" without selecting a prayer.
class DefaultPlaylistService {
  DefaultPlaylistService._();

  static Future<List<String>> getPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyPlaylist);
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>?;
      return list?.map((e) => e.toString()).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setPlaylist(List<String> prayerIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlaylist, jsonEncode(prayerIds));
  }

  static Future<bool> getShuffle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShuffle) ?? false;
  }

  static Future<void> setShuffle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShuffle, value);
  }

  /// Returns playlist in display order; if shuffle is true, returns a shuffled copy (does not persist order).
  static Future<List<String>> getPlaylistForPlayback() async {
    final list = await getPlaylist();
    final shuffle = await getShuffle();
    if (!shuffle || list.length <= 1) return List.from(list);
    final copy = List<String>.from(list)..shuffle();
    return copy;
  }
}
