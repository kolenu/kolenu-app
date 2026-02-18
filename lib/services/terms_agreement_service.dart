import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persists whether the user has accepted Terms of Service and Privacy Policy
/// on first launch (clickwrap-lite pattern).
///
/// Uses a file in the application cache directory (not SharedPreferences)
/// so it is reliably cleared when app data is cleared. On iOS, the cache
/// directory is excluded from iCloud backup, so it won't be restored on
/// reinstall.
class TermsAgreementService {
  TermsAgreementService._();

  static const String _filename = 'terms_agreed';

  /// Notifier for live updates. Set in main() from hasAgreed().
  /// Listen to this so the app can show the welcome screen when cleared.
  static final ValueNotifier<bool> agreedNotifier = ValueNotifier(true);

  static Future<File> _getFile() async {
    final dir = await getApplicationCacheDirectory();
    return File('${dir.path}/$_filename');
  }

  /// Returns true if the user has already tapped Continue on the welcome screen.
  static Future<bool> hasAgreed() async {
    final file = await _getFile();
    if (!await file.exists()) return false;
    final content = await file.readAsString();
    return content.trim() == '1';
  }

  /// Call when the user taps Continue on the welcome screen.
  static Future<void> setAgreed() async {
    final file = await _getFile();
    await file.writeAsString('1');
    agreedNotifier.value = true;
  }

  /// Clears the agreement (e.g. for testing). Welcome screen will show again.
  static Future<void> clearAgreed() async {
    final file = await _getFile();
    if (await file.exists()) await file.delete();
    agreedNotifier.value = false;
  }
}
