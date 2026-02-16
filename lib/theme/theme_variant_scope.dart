import 'package:flutter/material.dart';

import 'kolenu_theme.dart';

/// Provides the current theme variant and a callback to change it.
class ThemeVariantScope extends InheritedWidget {
  const ThemeVariantScope({
    super.key,
    required this.variant,
    required this.onVariantChanged,
    required super.child,
  });

  final KolenuThemeVariant variant;
  final ValueChanged<KolenuThemeVariant> onVariantChanged;

  static ThemeVariantScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeVariantScope>();
    assert(scope != null, 'No ThemeVariantScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(ThemeVariantScope oldWidget) {
    return variant != oldWidget.variant;
  }
}
