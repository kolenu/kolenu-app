# Kolenu (kolenu-app)

Kolenu is a Hebrew prayer learning application for teens and adults learning to read Hebrew prayers through synchronized audio-text highlighting, interactive repetition practice, and AI-powered pronunciation feedback.

## Features (Phase 1 — done)

- **Prayer list** — Shema and Modeh Ani; tap to open the reader.
- **Reader** — Hebrew text (RTL), word-by-word display with current-word highlighting synced to audio.
- **Audio** — Play/pause via `just_audio`; optional sentence mode (pause at sentence end, Repeat / Next). When audio is missing, **Play with TTS** uses device text-to-speech (Hebrew).
- **English tips** — Toggle “Tips” to show translations under each word; tap a word to show its translation.
- **Offline** — Content and audio load from assets; no network required.
- **Accessibility** — Semantics for play/pause, Sentence mode, Tips, Repeat/Next, list items, TTS button.

## Run

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter test
```

- **Unit:** `test/models/prayer_test.dart` — `PrayerListItem`, `WordSegment`, `PrayerContent` (fromJson, sentenceEndWordIndex).
- **Widget:** `test/widget_test.dart` — App title, list screen (Kolenu + loading/list/error), reader screen title.


## Licensing & Content

### Source Code License

The application source code in this repository is licensed under the
**Apache License 2.0**.

You are free to use, modify, and distribute the code in accordance
with that license. See the `LICENSE` file for full details.

See [LICENSE](LICENSE) for details.

---

### Content Notice (Very Important)

This repository does **NOT** include the actual content used by the
Kolenu app.

Specifically, the following are **excluded** from this repository and
are **NOT licensed** under the Apache License 2.0:

- Hebrew prayer texts
- Translations and transliterations
- Audio recordings
- Nusach, accent, or speed variations
- Educational or liturgical materials

All such content is proprietary and/or used under separate licenses
and permissions.

This repository contains **sample assets only**, for
development and demonstration purposes.

See [NOTICE](NOTICE) for details.

---

### Production Assets & Keys

This repository does not include production audio encryption keys or licensed audio access.

When built from source, Kolenu runs in "community mode" using placeholder keys.

Official App Store builds include access to licensed audio distributed via secure CDN.

---

### Trademark Notice

“Kolenu” and the Kolenu logo are trademarks of the Kolenu Project.

This license does not grant permission to use the project name, logo,
or branding for derivative works or distributions.

See [TRADEMARK.md](TRADEMARK.md) for details.


## Contributing

We welcome community contributions to the open-source app code! Please:
- Open issues or feature requests in the public repo
- Submit pull requests for code, documentation, or sample assets
- For questions, open a discussion or contact the maintainers

---

## Privacy Policy

For information about how we collect, use, and protect your data, please see our [PRIVACY_POLICY.md](PRIVACY_POLICY.md).

---

## Contact

For business inquiries, partnerships, or access to proprietary content, please contact the Kolenu team directly.

