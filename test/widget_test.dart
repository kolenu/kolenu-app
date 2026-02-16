// Widget tests for Kolenu app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolenu/main.dart';
import 'package:kolenu/screens/prayer_list_screen.dart';
import 'package:kolenu/screens/prayer_reader_screen.dart';
import 'package:kolenu/theme/kolenu_theme.dart';
import 'package:kolenu/theme/theme_variant_scope.dart';

void main() {
  testWidgets('App shows prayer list screen with title Kolenu',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KolenuApp(initialThemeVariant: KolenuThemeVariant.meadow));
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Kolenu').evaluate().isNotEmpty) break;
    }
    expect(find.text('Kolenu'), findsOneWidget);
  });

  testWidgets('Prayer list screen shows Kolenu and loading or list or error',
      (WidgetTester tester) async {
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
    final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    expect(hasList || hasError || hasLoading, isTrue);
  });

  testWidgets('Prayer reader loads and shows title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
