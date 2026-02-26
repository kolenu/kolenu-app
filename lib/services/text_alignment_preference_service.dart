import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyTextAlignment = 'text_alignment';

/// Text alignment for prayer content. Right matches traditional siddur layout.
enum TextAlignmentOption {
  right('Right (Traditional)', TextAlign.right),
  center('Center (Learning mode)', TextAlign.center);

  const TextAlignmentOption(this.label, this.textAlign);
  final String label;
  final TextAlign textAlign;
}

/// Persists text alignment preference for prayer display.
class TextAlignmentPreferenceService {
  TextAlignmentPreferenceService._();

  /// Notifier for live updates when user changes alignment in Settings.
  static final ValueNotifier<TextAlignmentOption> optionNotifier =
      ValueNotifier<TextAlignmentOption>(TextAlignmentOption.right);

  static Future<TextAlignmentOption> getOption() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyTextAlignment);
    if (name == null) return TextAlignmentOption.right;
    final index =
        TextAlignmentOption.values.indexWhere((v) => v.name == name);
    return index >= 0
        ? TextAlignmentOption.values[index]
        : TextAlignmentOption.right;
  }

  static Future<void> setOption(TextAlignmentOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTextAlignment, option.name);
    optionNotifier.value = option;
  }
}
