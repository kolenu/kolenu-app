import 'package:flutter/material.dart';

import '../theme/kolenu_theme.dart';
import '../theme/theme_variant_scope.dart';

/// Logo for app bar and hero. No frame.
class KolenuLogo extends StatelessWidget {
  const KolenuLogo({
    super.key,
    this.size = 80,
    this.width,
    this.height,
    this.variant,
  });

  final double size;
  /// If set, logo uses this width (e.g. for a longer app bar logo).
  final double? width;
  /// If set, logo uses this height.
  final double? height;
  final KolenuThemeVariant? variant;

  double get _w => width ?? size;
  double get _h => height ?? size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = variant ?? ThemeVariantScope.of(context).variant;
    final asset = v.logoAsset;

    final image = Image.asset(
      asset,
      width: _w,
      height: _h,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _FallbackLogo(
        size: _h,
        color: theme.colorScheme.primary,
      ),
    );

    return ClipRect(
      child: SizedBox(
        width: _w,
        height: _h,
        child: image,
      ),
    );
  }
}

/// Fallback when logo image is missing: book icon, no background.
class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.menu_book_rounded,
      size: size,
      color: color,
    );
  }
}
