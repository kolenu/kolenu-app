import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _keyCompletedPrayers = 'progress_completed_prayers';
const String _keyOpenDates = 'progress_open_dates';
const String _keyLastPracticed = 'progress_last_practiced';
const String _keyLastPracticedChipShown = 'progress_last_practiced_chip_shown';

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

  /// Last practiced prayer ID and date. Used for home screen chip.
  static Future<({String? prayerId, String date})> getLastPracticed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastPracticed);
    if (raw == null) return (prayerId: null, date: '');
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      return (
        prayerId: map?['id'] as String?,
        date: map?['date'] as String? ?? '',
      );
    } catch (_) {
      return (prayerId: null, date: '');
    }
  }

  static Future<void> setLastPracticed(String prayerId) async {
    final prefs = await SharedPreferences.getInstance();
    final date = _todayYyyyMmDd();
    await prefs.setString(
      _keyLastPracticed,
      jsonEncode({'id': prayerId, 'date': date}),
    );
  }

  /// Whether the "Last practiced" chip has been shown before. Show only on first app open.
  static Future<bool> hasShownLastPracticedChip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLastPracticedChipShown) ?? false;
  }

  static Future<void> markLastPracticedChipShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLastPracticedChipShown, true);
  }

  /// Human-readable relative date: "Today", "Yesterday", "2 days ago", etc.
  static String formatRelativeDate(String yyyyMmDd) {
    final d = DateTime.tryParse(yyyyMmDd);
    if (d == null) return yyyyMmDd;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final then = DateTime(d.year, d.month, d.day);
    final diff = today.difference(then).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff >= 2 && diff <= 6) return '$diff days ago';
    if (diff >= 7 && diff < 14) return 'Last week';
    if (diff >= 14 && diff < 30) return '${diff ~/ 7} weeks ago';
    return yyyyMmDd;
  }

  static String _prevDay(String yyyyMmDd) {
    final d = DateTime.tryParse(yyyyMmDd);
    if (d == null) return yyyyMmDd;
    final prev = d.subtract(const Duration(days: 1));
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}-${prev.day.toString().padLeft(2, '0')}';
  }
}
