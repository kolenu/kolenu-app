# Kolenu (kolenu-app)

Kolenu is a Hebrew prayer learning application for teens and adults learning to read Hebrew prayers through synchronized audio-text highlighting, interactive repetition practice, and AI-powered pronunciation feedback.

## Features

- **Prayer list** — Tap to open the reader.
- **Reader** — Hebrew text, word-by-word display with current-word highlighting synced to audio.
- **Audio** — Play/pause; optional sentence mode (pause at sentence end, Repeat / Next). When audio is missing, **Play with TTS** uses device text-to-speech (Hebrew).
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
**BSL 1.2 (Business Source License 1.2)**.

Additional Use Grant:
- Non-commercial use allowed
- No commercial prayer / music streaming apps
- No SaaS or subscription-based religious audio services

Change Date: 2030-02-17

You are free to use, modify, and distribute the code in accordance
with that license. See the `LICENSE` file for full details.

See [LICENSE](LICENSE) for details.

---

### Content Notice (Very Important)

This repository does **NOT** include the actual content used by the
Kolenu app.

Specifically, the following are **excluded** from this repository and
are **NOT licensed** under BSL 1.2:

- Hebrew prayer texts
- Translations and transliterations
- Melody, song and audio recordings
- Nusach, accent, or speed variations
- Educational or liturgical materials


All such content is proprietary and/or used under separate licenses
and permissions from us or third-party providers.

This repository contains **sample assets only**, for
development and demonstration purposes.

See [NOTICE](NOTICE) for details.

---

### Important Usage Notice

Kolenu provides Jewish prayer content, melodies, and guidance for personal, educational, and religious study purposes. While we aim for accuracy, Kolenu does not guarantee completeness, correctness, or suitability for any particular practice or ritual.

Users should not rely solely on Kolenu for religious decisions or guidance. Always consult a qualified rabbi, cantor, or teacher for personal or communal matters.

Kolenu is not a substitute for professional advice in health, safety, or legal matters.

For the full usage disclaimer and IP reporting procedures, see [USAGE_DISCLAIMER.md](USAGE_DISCLAIMER.md).

---

### Copyright Disclaimer & Takedown Policy

For detailed information about copyright ownership, licensing of specific
content, and our "Notice and Notice" takedown procedure to report copyright
concerns, please see [COPYRIGHT_DISCLAIMER.md](COPYRIGHT_DISCLAIMER.md).

Contact: info@digimint.ca

---

### Production Assets & Keys

This repository does not include production audio encryption keys or licensed audio access.

When built from source, Kolenu runs in "community mode" using placeholder keys.

Official App Store builds include access to licensed audio distributed via secure CDN.

---

### Trademark Notice

“Kolenu” and the Kolenu logo are trademarks of the DigiMint Inc.

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

