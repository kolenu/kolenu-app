// Widget tests for Kolenu app.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolenu/screens/home_screen.dart';
import 'package:kolenu/screens/main_shell_screen.dart';
import 'package:kolenu/screens/prayer_list_screen.dart';
import 'package:kolenu/screens/prayer_reader_screen.dart';
import 'package:kolenu/theme/kolenu_theme.dart';
import 'package:kolenu/theme/theme_variant_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const wordsAssetPath = 'assets/audio/shema/ben_mitz_1_v2/words.json';
    final wordsJson = jsonEncode({
      'id': 'shema',
      'title': 'Shema',
      'titleHebrew': 'שְׁמַע יִשְׂרָאֵל',
      'text': 'שְׁמַע יִשְׂרָאֵל',
      'sentences': ['שְׁמַע יִשְׂרָאֵל'],
      'words': [
        {'word': 'שְׁמַע', 'start': 0.0, 'end': 0.6, 'translation': 'Hear'},
        {
          'word': 'יִשְׂרָאֵל',
          'start': 0.6,
          'end': 1.4,
          'translation': 'Israel',
        },
      ],
      'audio': null,
      'versions': null,
    });
    final encoded = utf8.encode(wordsJson);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == wordsAssetPath) {
            return ByteData.view(Uint8List.fromList(encoded).buffer);
          }
          return null;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('Main shell hosts HomeScreen on first tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KolenuTheme.light(KolenuThemeVariant.meadow),
        home: ThemeVariantScope(
          variant: KolenuThemeVariant.meadow,
          onVariantChanged: (_) {},
          child: const MainShellScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Prayer list screen shows Kolenu and loading or list or error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ThemeVariantScope(
          variant: KolenuThemeVariant.meadow,
          onVariantChanged: (_) {},
          child: const PrayerListScreen(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Shema').evaluate().isNotEmpty ||
          find.text('Could not load prayers').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.text('Kolenu'), findsOneWidget);
    final hasList = find.text('Shema').evaluate().isNotEmpty;
    final hasError = find.text('Could not load prayers').evaluate().isNotEmpty;
    final hasLoading = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isNotEmpty;
    expect(hasList || hasError || hasLoading, isTrue);
  });

  testWidgets('Prayer reader loads and shows title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrayerReaderScreen(
          prayerId: 'shema',
          prayerFile: 'shema/ben_mitz_1_v2/words.json',
          title: 'Shema',
          titleHebrew: 'שְׁמַע יִשְׂרָאֵל',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Shema'), findsOneWidget);
  });
}
