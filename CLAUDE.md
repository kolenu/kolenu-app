# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (wraps flutter run, prompts for debug/release, injects env keys if set)
./run.sh

# Run tests
flutter test

# Run a single test file
flutter test test/models/prayer_test.dart

# Static analysis
flutter analyze

# Format code
dart format .

# Full local CI check (format → analyze → test)
./run_ci.sh

# Regenerate app icons from assets/images/kolenu_lamb_logo.png
dart run flutter_launcher_icons
```

### Environment Keys

The app uses encrypted audio from a CDN. Keys are injected at build time via `--dart-define`. Without them, the app builds in "community mode" with embedded dummy keys:

```bash
source setenv.sh <version>   # e.g. source setenv.sh dummy
./run.sh                     # then run
```

Keys: `KOLENU_KEY_NAME`, `KOLENU_AUDIO_KEY`, `KOLENU_DOWNLOAD_KEY`.

## Architecture

### Content Data Flow

Content is structured around prayers with word-level timestamps. Two content sources exist:

1. **Bundled assets** (`assets/audio/`): `index.json` lists prayers; each prayer folder has `words.json` (word timing array) and optionally `text.json` (display text with lines). Audio files are plain `.mp3`.

2. **Cloud CDN** (`cloud.kolenu.net/{release}/`): `index.json` lists songs in `{category}/{songId}` folder layout. Audio is AES-256-CBC encrypted `.enc` files. `CloudIndexService` fetches and caches the index; `SongDownloadService` downloads song folders on demand; `AudioDecryptionService` decrypts using `KOLENU_AUDIO_KEY` before playback.

`PrayerService` loads content from both assets and local downloads. Cloud content takes priority when available.

### Core Models (`lib/models/prayer.dart`)

- `PrayerListItem` — list entry (id, title, category, recordings)
- `WordSegment` — one word with `start`/`end` timestamps, optional `translation`/`transliteration`
- `PrayerContent` — full prayer: `words[]`, `sentences[]`, `sentenceEndWordIndices[]`, `recordings[]`
- `RecordingOption` — one audio version for a prayer

### Navigation

`MainShellScreen` is a bottom-nav shell with three tabs:
- **Home** → `HomeScreen` (hub: Continue Learning, Start Learning pillars, Community Voices stub, Settings); **See all prayers** and category rows push `PrayerListScreen` (full list or filtered by category bucket)
- **Learn** → `HebrewBasicsScreen`
- **About** → `AboutScreen`

`PrayerReaderScreen` opens on top when a prayer is selected. It drives audio playback (via `just_audio`) and syncs word highlighting to the current playback position using word timestamps.

### Services Pattern

Each user preference is its own service file (e.g. `ThemePreferenceService`, `FontSizePreferenceService`). They use `shared_preferences` for persistence and expose a `ValueNotifier` for reactive UI updates. `main.dart` reads all initial preference values before `runApp`.

### Theming

Three theme variants: `KolenuThemeVariant.meadow`, `.sunset`, `.forest`. Each has light/dark color schemes defined in `KolenuTheme`. The active variant is stored in `ThemeVariantScope` (an `InheritedWidget`) and the app observes system dark-mode automatically (`ThemeMode.system`).

### Key Config Files

- `lib/config/env_config.dart` — reads `--dart-define` values, falls back to `EmbeddedKeys`
- `lib/config/cdn_config.dart` — CDN base URL (`https://cloud.kolenu.net/{release}/`)
- `lib/config/embedded_keys.dart` — dummy keys for community builds (do not commit real keys)

## Linter Rules

`analysis_options.yaml` treats `unused_local_variable`, `unused_import`, and `dead_code` as **errors**. Key enforced rules: `avoid_print`, `prefer_const_constructors`, `prefer_final_locals`, `always_declare_return_types`, `unawaited_futures`. Run `./run_ci.sh` before pushing to catch all issues.

## Asset Gotchas

- `pubspec.yaml` lists each asset subdirectory explicitly (Flutter does not recurse automatically).
- `encrypt` package is pinned at `5.0.3` — do not upgrade without verifying AES-CBC padding still works.
- `path_provider_foundation` is pinned at `2.4.3` to avoid Objective-C FFI failures on the iOS simulator.
