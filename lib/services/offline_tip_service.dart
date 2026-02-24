import 'package:shared_preferences/shared_preferences.dart';

const String _keyOfflineTipShown = 'offline_tip_shown';

/// Tracks whether the first-time offline tip has been shown.
class OfflineTipService {
  OfflineTipService._();

  static Future<bool> hasShownTip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOfflineTipShown) ?? false;
  }

  static Future<void> markTipShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOfflineTipShown, true);
  }
}
