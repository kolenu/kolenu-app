import 'package:flutter/material.dart';

import 'config/env_config.dart';

import 'screens/main_shell_screen.dart';
import 'services/song_download_service.dart';
import 'services/theme_preference_service.dart';
import 'theme/kolenu_theme.dart';
import 'theme/theme_variant_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('EnvConfig: keyName=${EnvConfig.keyName}');
  debugPrint('EnvConfig: downloadKeySet=${EnvConfig.downloadKey.isNotEmpty}');
  debugPrint('EnvConfig: audioKeySet=${EnvConfig.audioKey.isNotEmpty}');
  await SongDownloadService.cleanupDownloadsOnStart();
  final initialVariant = await ThemePreferenceService.getVariant();
  runApp(KolenuApp(initialThemeVariant: initialVariant));
}

class KolenuApp extends StatefulWidget {
  const KolenuApp({
    super.key,
    required this.initialThemeVariant,
  });

  final KolenuThemeVariant initialThemeVariant;

  @override
  State<KolenuApp> createState() => _KolenuAppState();
}

class _KolenuAppState extends State<KolenuApp> {
  late KolenuThemeVariant _variant;

  @override
  void initState() {
    super.initState();
    _variant = widget.initialThemeVariant;
  }

  void _onVariantChanged(KolenuThemeVariant variant) {
    setState(() => _variant = variant);
    ThemePreferenceService.setVariant(variant);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeVariantScope(
      variant: _variant,
      onVariantChanged: _onVariantChanged,
      child: MaterialApp(
        title: 'Kolenu',
        theme: KolenuTheme.light(_variant),
        darkTheme: KolenuTheme.dark(_variant),
        themeMode: ThemeMode.system,
        home: const MainShellScreen(),
      ),
    );
  }
}
