import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyTextAlignment = 'text_alignment';

/// Text alignment for prayer content. Only center or RTL; app ignores system LTR.
/// RTL is default (traditional siddur layout).
enum TextAlignmentOption {
  rtl('Right', TextAlign.right),
  center('Center', TextAlign.center);

  const TextAlignmentOption(this.label, this.textAlign);
  final String label;
  final TextAlign textAlign;
}

/// Persists text alignment preference for prayer display.
class TextAlignmentPreferenceService {
  TextAlignmentPreferenceService._();

  /// Notifier for live updates when user changes alignment in Settings.
  static final ValueNotifier<TextAlignmentOption> optionNotifier =
      ValueNotifier<TextAlignmentOption>(TextAlignmentOption.rtl);

  static Future<TextAlignmentOption> getOption() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyTextAlignment);
    if (name == null) return TextAlignmentOption.rtl;
    // Migrate legacy "right" to "rtl"
    if (name == 'right') return TextAlignmentOption.rtl;
    final index = TextAlignmentOption.values.indexWhere((v) => v.name == name);
    return index >= 0
        ? TextAlignmentOption.values[index]
        : TextAlignmentOption.rtl;
  }

  static Future<void> setOption(TextAlignmentOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTextAlignment, option.name);
    optionNotifier.value = option;
  }
}
