import 'package:flutter/material.dart';

/// Kolenu app theme: warm, gentle palettes with a cute lamb mascot feel.
/// Three variants (Meadow, Sunset, Forest), each with its own logo and colors.
/// For teens and adults (ages 13–40).
enum KolenuThemeVariant {
  meadow,
  sunset,
  forest,
}

extension KolenuThemeVariantExtension on KolenuThemeVariant {
  String get displayName {
    switch (this) {
      case KolenuThemeVariant.meadow:
        return 'Meadow';
      case KolenuThemeVariant.sunset:
        return 'Sunset';
      case KolenuThemeVariant.forest:
        return 'Forest';
    }
  }

  String get logoAsset => 'assets/images/kolenu_lamb_logo.png';
}

class KolenuTheme {
  KolenuTheme._();

  /// Default logo asset (Meadow) for backwards compatibility.
  static const String lambLogoAsset = 'assets/images/kolenu_lamb_logo.png';

  static ColorScheme _colorSchemeMeadowLight() {
    return const ColorScheme(
      primary: Color(0xFF7B9B6D),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE8F0E4),
      onPrimaryContainer: Color(0xFF2D3D28),
      secondary: Color(0xFFB8956B),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF5EDE0),
      onSecondaryContainer: Color(0xFF4A3C28),
      tertiary: Color(0xFF9BB88A),
      surface: Color(0xFFFFFBF7),
      onSurface: Color(0xFF2C2825),
      surfaceContainerHighest: Color(0xFFF5F0E8),
      onSurfaceVariant: Color(0xFF5C564E),
      outline: Color(0xFFA89F94),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      brightness: Brightness.light,
    );
  }

  static ColorScheme _colorSchemeMeadowDark() {
    return const ColorScheme(
      primary: Color(0xFF8FAD7F),
      onPrimary: Color(0xFF1A2616),
      primaryContainer: Color(0xFF3D5235),
      onPrimaryContainer: Color(0xFFE8F0E4),
      secondary: Color(0xFFD4B896),
      onSecondary: Color(0xFF2E2518),
      secondaryContainer: Color(0xFF4A3C28),
      onSecondaryContainer: Color(0xFFF5EDE0),
      tertiary: Color(0xFF9BB88A),
      surface: Color(0xFF1A1816),
      onSurface: Color(0xFFE8E4DE),
      surfaceContainerHighest: Color(0xFF2C2825),
      onSurfaceVariant: Color(0xFFB8AFA5),
      outline: Color(0xFF6B6359),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      brightness: Brightness.dark,
    );
  }

  static ColorScheme _colorSchemeSunsetLight() {
    return const ColorScheme(
      primary: Color(0xFFC97B4A),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFBE8DE),
      onPrimaryContainer: Color(0xFF4A2818),
      secondary: Color(0xFFB85C3E),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFDAD4),
      onSecondaryContainer: Color(0xFF3D1510),
      tertiary: Color(0xFFE8A872),
      surface: Color(0xFFFFF8F5),
      onSurface: Color(0xFF2C2522),
      surfaceContainerHighest: Color(0xFFF5EDE8),
      onSurfaceVariant: Color(0xFF5C5048),
      outline: Color(0xFFA89A90),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      brightness: Brightness.light,
    );
  }

  static ColorScheme _colorSchemeSunsetDark() {
    return const ColorScheme(
      primary: Color(0xFFE8A072),
      onPrimary: Color(0xFF2E1810),
      primaryContainer: Color(0xFF6B4028),
      onPrimaryContainer: Color(0xFFFBE8DE),
      secondary: Color(0xFFE8B4A8),
      onSecondary: Color(0xFF3D1510),
      secondaryContainer: Color(0xFF5C3028),
      onSecondaryContainer: Color(0xFFFFDAD4),
      tertiary: Color(0xFFE8A872),
      surface: Color(0xFF1A1614),
      onSurface: Color(0xFFE8E2DE),
      surfaceContainerHighest: Color(0xFF2C2522),
      onSurfaceVariant: Color(0xFFB8A89E),
      outline: Color(0xFF6B5C54),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      brightness: Brightness.dark,
    );
  }

  static ColorScheme _colorSchemeForestLight() {
    return const ColorScheme(
      primary: Color(0xFF2D6B4A),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFB8E8D4),
      onPrimaryContainer: Color(0xFF0A2E20),
      secondary: Color(0xFF4A6B5C),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD4E8E0),
      onSecondaryContainer: Color(0xFF1A2E28),
      tertiary: Color(0xFF5C8B6E),
      surface: Color(0xFFF5FAF8),
      onSurface: Color(0xFF1A2522),
      surfaceContainerHighest: Color(0xFFE8F0EC),
      onSurfaceVariant: Color(0xFF3D5048),
      outline: Color(0xFF6B7A72),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      brightness: Brightness.light,
    );
  }

  static ColorScheme _colorSchemeForestDark() {
    return const ColorScheme(
      primary: Color(0xFF8FD4B0),
      onPrimary: Color(0xFF0A2E20),
      primaryContainer: Color(0xFF2D6B4A),
      onPrimaryContainer: Color(0xFFB8E8D4),
      secondary: Color(0xFFA8C4B8),
      onSecondary: Color(0xFF1A2E28),
      secondaryContainer: Color(0xFF3D5048),
      onSecondaryContainer: Color(0xFFD4E8E0),
      tertiary: Color(0xFF8FD4B0),
      surface: Color(0xFF121A18),
      onSurface: Color(0xFFE0E8E4),
      surfaceContainerHighest: Color(0xFF1A2522),
      onSurfaceVariant: Color(0xFFA8B8B0),
      outline: Color(0xFF5C6B64),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      brightness: Brightness.dark,
    );
  }

  static ColorScheme colorSchemeLight(KolenuThemeVariant variant) {
    switch (variant) {
      case KolenuThemeVariant.meadow:
        return _colorSchemeMeadowLight();
      case KolenuThemeVariant.sunset:
        return _colorSchemeSunsetLight();
      case KolenuThemeVariant.forest:
        return _colorSchemeForestLight();
    }
  }

  static ColorScheme colorSchemeDark(KolenuThemeVariant variant) {
    switch (variant) {
      case KolenuThemeVariant.meadow:
        return _colorSchemeMeadowDark();
      case KolenuThemeVariant.sunset:
        return _colorSchemeSunsetDark();
      case KolenuThemeVariant.forest:
        return _colorSchemeForestDark();
    }
  }

  static ThemeData _buildTheme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: scheme.surfaceContainerHighest,
        indicatorColor: scheme.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onSecondaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            );
          }
          return TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(88, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(88, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
    );
  }

  static ThemeData light(KolenuThemeVariant variant) {
    return _buildTheme(colorSchemeLight(variant));
  }

  static ThemeData dark(KolenuThemeVariant variant) {
    return _buildTheme(colorSchemeDark(variant));
  }
}
