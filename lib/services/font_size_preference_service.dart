import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyFontScale = 'font_scale';

/// Font size scale factor. 1.0 = default.
enum FontSizeOption {
  small(0.85, 'Small'),
  medium(1.0, 'Medium'),
  large(1.2, 'Large');

  const FontSizeOption(this.scale, this.label);
  final double scale;
  final String label;
}

/// Persists text size preference for accessibility.
class FontSizePreferenceService {
  FontSizePreferenceService._();

  /// Notifier for live updates when user changes font size in Settings.
  static final ValueNotifier<FontSizeOption> optionNotifier =
      ValueNotifier<FontSizeOption>(FontSizeOption.medium);

  static Future<FontSizeOption> getOption() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyFontScale);
    if (name == null) return FontSizeOption.medium;
    final index = FontSizeOption.values.indexWhere((v) => v.name == name);
    return index >= 0 ? FontSizeOption.values[index] : FontSizeOption.medium;
  }

  static Future<void> setOption(FontSizeOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontScale, option.name);
    optionNotifier.value = option;
  }

  static TextScaler textScalerFor(FontSizeOption option) {
    return TextScaler.linear(option.scale);
  }
}
