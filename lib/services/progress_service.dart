import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _keyCompletedPrayers = 'progress_completed_prayers';
const String _keyOpenDates = 'progress_open_dates';

/// Tracks which prayers were completed and open dates for streak.
class ProgressService {
  ProgressService._();

  static Future<Set<String>> getCompletedPrayerIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCompletedPrayers);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      return list?.map((e) => e as String).toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> markPrayerCompleted(String prayerId) async {
    final set = await getCompletedPrayerIds();
    if (set.contains(prayerId)) return;
    set.add(prayerId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCompletedPrayers, jsonEncode(set.toList()));
  }

  static Future<void> recordOpenDate(String dateYyyyMmDd) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyOpenDates);
    List<String> dates = [];
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>?;
        if (list != null) dates = list.map((e) => e as String).toList();
      } catch (_) {}
    }
    if (dates.contains(dateYyyyMmDd)) return;
    dates.add(dateYyyyMmDd);
    dates.sort((a, b) => b.compareTo(a));
    if (dates.length > 365) dates = dates.sublist(0, 365);
    await prefs.setString(_keyOpenDates, jsonEncode(dates));
  }

  /// Returns current streak: consecutive days (including today) with at least one open.
  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyOpenDates);
    if (raw == null) return 0;
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null || list.isEmpty) return 0;
      final dates = list.map((e) => e as String).toList();
      String expected = _todayYyyyMmDd();
      int streak = 0;
      for (final s in dates) {
        if (s == expected) {
          streak++;
          expected = _prevDay(expected);
        } else if (s.compareTo(expected) < 0) {
          break;
        }
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }

  static String _todayYyyyMmDd() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String _prevDay(String yyyyMmDd) {
    final d = DateTime.tryParse(yyyyMmDd);
    if (d == null) return yyyyMmDd;
    final prev = d.subtract(const Duration(days: 1));
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}-${prev.day.toString().padLeft(2, '0')}';
  }
}
