import 'package:flutter/material.dart';

import '../data/hebrew_alphabet.dart';
import '../services/alphabet_sound_service.dart';
import '../theme/theme_variant_scope.dart';

/// Hebrew Basics for Prayer: alphabet and vowels (nikud) overview.
/// See doc/design/hebrew_alphabet.md.
/// Plays sounds from MP3 assets (assets/sounds/alphabet/, assets/sounds/vowels/) when present,
/// Plays from encrypted .enc assets when available.
class HebrewBasicsScreen extends StatefulWidget {
  const HebrewBasicsScreen({super.key});

  @override
  State<HebrewBasicsScreen> createState() => _HebrewBasicsScreenState();
}

class _HebrewBasicsScreenState extends State<HebrewBasicsScreen> {
  final AlphabetSoundService _soundService = AlphabetSoundService();

  @override
  void dispose() {
    _soundService.dispose();
    super.dispose();
  }

  Future<void> _speakLetter(HebrewLetter letter) async {
    await _soundService.playLetter(letter);
  }

  Future<void> _speakVowel(HebrewVowel vowel) async {
    await _soundService.playVowel(vowel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ThemeVariantScope.of(context); // require scope

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_rounded,
              color: theme.colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text('Hebrew Basics'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Tap any letter or vowel to hear its name and sound.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Letters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Some consonants have a dot (dagesh) inside: with dot and without dot sound different (e.g. בּ b, ב v).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _LettersGrid(onTap: _speakLetter),
              const SizedBox(height: 28),
              Text(
                'Vowels (Nikud)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nikud (vowel marks) are the dots and lines under or inside letters. Prayer-relevant vowels:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _VowelsList(onTap: _speakVowel),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _LettersGrid extends StatelessWidget {
  const _LettersGrid({required this.onTap});

  final ValueChanged<HebrewLetter> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossCount = 4;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
        final cellSize = width.clamp(72.0, 96.0);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: hebrewLetters.map((letter) {
            final hasDagesh = letter.hasDagesh && letter.charWithDagesh != null;
            final soundLabel = letter.sound.isEmpty
                ? 'silent'
                : (hasDagesh && letter.soundWithoutDagesh != null
                      ? '${letter.sound} / ${letter.soundWithoutDagesh}'
                      : letter.sound);
            return SizedBox(
              width: cellSize,
              height: cellSize,
              child: Semantics(
                label: '${letter.name}, $soundLabel',
                button: true,
                child: Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onTap(letter),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasDagesh)
                            Text(
                              '${letter.charWithDagesh} ${letter.char}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                height: 1.2,
                              ),
                              textDirection: TextDirection.rtl,
                            )
                          else
                            Text(
                              letter.char,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                height: 1.2,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            letter.sound.isEmpty
                                ? '—'
                                : (hasDagesh &&
                                          letter.soundWithoutDagesh != null
                                      ? '${letter.sound} / ${letter.soundWithoutDagesh}'
                                      : letter.sound),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _VowelsList extends StatelessWidget {
  const _VowelsList({required this.onTap});

  final ValueChanged<HebrewVowel> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: hebrewVowels.map((vowel) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            label: '${vowel.name}, ${vowel.soundDesc}',
            button: true,
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onTap(vowel),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          vowel.symbolWithBet,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            height: 1.2,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vowel.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              vowel.soundDesc,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
