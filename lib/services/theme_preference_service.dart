import 'package:shared_preferences/shared_preferences.dart';

import '../theme/kolenu_theme.dart';

const String _keyThemeVariant = 'theme_variant';

/// Persists the selected theme variant (Meadow, Sunset, Forest).
class ThemePreferenceService {
  ThemePreferenceService._();

  static Future<KolenuThemeVariant> getVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyThemeVariant);
    if (name == null) return KolenuThemeVariant.meadow;
    final index =
        KolenuThemeVariant.values.indexWhere((v) => v.name == name);
    return index >= 0
        ? KolenuThemeVariant.values[index]
        : KolenuThemeVariant.meadow;
  }

  static Future<void> setVariant(KolenuThemeVariant variant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeVariant, variant.name);
  }
}
