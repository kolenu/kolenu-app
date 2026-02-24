import 'package:flutter/material.dart';

import 'config/env_config.dart';

import 'screens/main_shell_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/cache_keys_service.dart';
import 'services/font_size_preference_service.dart';
import 'services/orientation_preference_service.dart';
import 'services/song_download_service.dart';
import 'services/terms_agreement_service.dart';
import 'services/theme_preference_service.dart';
import 'theme/kolenu_theme.dart';
import 'theme/theme_variant_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('EnvConfig: release=${EnvConfig.release}');
  await CacheKeysService.checkKeysAndClearIfChanged();
  await SongDownloadService.cleanupDownloadsOnStart();
  await OrientationPreferenceService.applyStoredOrientation();
  final initialVariant = await ThemePreferenceService.getVariant();
  FontSizePreferenceService.optionNotifier.value =
      await FontSizePreferenceService.getOption();
  final hasAgreedTerms = await TermsAgreementService.hasAgreed();
  TermsAgreementService.agreedNotifier.value = hasAgreedTerms;
  runApp(
    KolenuApp(
      initialThemeVariant: initialVariant,
      hasAgreedTerms: hasAgreedTerms,
    ),
  );
}

class KolenuApp extends StatefulWidget {
  const KolenuApp({
    super.key,
    required this.initialThemeVariant,
    required this.hasAgreedTerms,
  });

  final KolenuThemeVariant initialThemeVariant;
  final bool hasAgreedTerms; // Initial value; live updates via agreedNotifier

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

  void _onTermsAgreed() {
    TermsAgreementService.setAgreed();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeVariantScope(
      variant: _variant,
      onVariantChanged: _onVariantChanged,
      child: ValueListenableBuilder<FontSizeOption>(
        valueListenable: FontSizePreferenceService.optionNotifier,
        builder: (context, fontOption, _) {
          final textScaler = FontSizePreferenceService.textScalerFor(
            fontOption,
          );
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: ValueListenableBuilder<bool>(
              valueListenable: TermsAgreementService.agreedNotifier,
              builder: (context, hasAgreedTerms, _) {
                return MaterialApp(
                  title: 'Kolenu',
                  theme: KolenuTheme.light(_variant),
                  darkTheme: KolenuTheme.dark(_variant),
                  themeMode: ThemeMode.system,
                  home: hasAgreedTerms
                      ? const MainShellScreen()
                      : WelcomeScreen(onContinue: _onTermsAgreed),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
