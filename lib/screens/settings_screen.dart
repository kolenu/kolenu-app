import 'package:flutter/material.dart';

import '../config/cdn_config.dart';
import '../data/playback_mode.dart';
import '../services/cloud_index_service.dart';
import '../services/default_playlist_service.dart';
import '../services/loop_preference_service.dart';
import 'playlist_screen.dart';
import 'support_kolenu_screen.dart';
import '../services/font_size_preference_service.dart';
import '../services/orientation_preference_service.dart';
import '../services/text_alignment_preference_service.dart';
import '../services/song_download_service.dart';
import '../services/terms_agreement_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _lockPortrait = false;
  FontSizeOption _fontSize = FontSizeOption.medium;
  TextAlignmentOption _textAlignment = TextAlignmentOption.rtl;
  PlaybackMode _playbackMode = PlaybackMode.playOnce;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final lock = await OrientationPreferenceService.getLockPortrait();
    final font = await FontSizePreferenceService.getOption();
    final alignment = await TextAlignmentPreferenceService.getOption();
    final mode = await LoopPreferenceService.getPlaybackMode();
    if (mounted) {
      setState(() {
        _lockPortrait = lock;
        _fontSize = font;
        _textAlignment = alignment;
        _playbackMode = mode;
      });
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearStorageAndReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear storage and reset?'),
        content: const Text(
          'Remove all downloaded songs and reset the welcome screen. Use when switching CDN releases or to test the first-launch flow. You can re-download songs after.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear and reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      if (CdnConfig.isCloudEnabled) {
        await SongDownloadService.clearAllSongs();
        await CloudIndexService.clearCache();
      }
      await TermsAgreementService.clearAgreed();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sectionLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('PLAYLIST', style: sectionLabelStyle),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Edit default playlist'),
                    subtitle: const Text(
                      'Choose and order prayers for the default playlist.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const PlaylistScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('Playback mode'),
                    subtitle: Text(_playbackMode.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final chosen =
                          await showModalBottomSheet<PlaybackMode>(
                            context: context,
                            builder: (ctx) {
                              final t = Theme.of(ctx);
                              final cs = t.colorScheme;
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 8),
                                    Center(
                                      child: Container(
                                        width: 32,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: cs.onSurfaceVariant
                                              .withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        8,
                                      ),
                                      child: Text(
                                        'Playback mode',
                                        style: t.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ...PlaybackMode.values.map(
                                      (m) => ListTile(
                                        title: Text(m.label),
                                        trailing: _playbackMode == m
                                            ? Icon(
                                                Icons.check,
                                                color: cs.primary,
                                              )
                                            : null,
                                        onTap: () => Navigator.pop(ctx, m),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                      if (chosen != null && mounted) {
                        setState(() => _playbackMode = chosen);
                        await LoopPreferenceService.setPlaybackMode(chosen);
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('Play default playlist'),
                    subtitle: const Text(
                      'Start playing the playlist from the beginning.',
                    ),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () async {
                      final ids =
                          await DefaultPlaylistService.getPlaylistForPlayback();
                      if (ids.isEmpty && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Playlist is empty. Add prayers in Edit default playlist.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop('play_playlist');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('SUPPORT', style: sectionLabelStyle),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.favorite, color: colorScheme.primary),
                title: const Text('Support Kolenu'),
                subtitle: const Text(
                  'Help us record high-quality Hebrew audio.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const SupportKolenuScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text('DISPLAY', style: sectionLabelStyle),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Lock to portrait'),
                    subtitle: const Text(
                      'When on, the app stays in portrait mode. When off, you can rotate to landscape.',
                    ),
                    value: _lockPortrait,
                    onChanged: (v) async {
                      setState(() => _lockPortrait = v);
                      await OrientationPreferenceService.setLockPortrait(v);
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Text size',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<FontSizeOption>(
                            segments: FontSizeOption.values
                                .map(
                                  (o) => ButtonSegment(
                                    value: o,
                                    label: Text(o.label),
                                  ),
                                )
                                .toList(),
                            selected: {_fontSize},
                            onSelectionChanged: (s) async {
                              final v = s.first;
                              setState(() => _fontSize = v);
                              await FontSizePreferenceService.setOption(v);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Text alignment',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<TextAlignmentOption>(
                            segments: TextAlignmentOption.values
                                .map(
                                  (o) => ButtonSegment(
                                    value: o,
                                    label: Text(o.label),
                                  ),
                                )
                                .toList(),
                            selected: {_textAlignment},
                            onSelectionChanged: (s) async {
                              final v = s.first;
                              setState(() => _textAlignment = v);
                              await TextAlignmentPreferenceService.setOption(v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('STORAGE', style: sectionLabelStyle),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download prayers to listen without internet. Tap a prayer to download it — the pin icon shows which are cached.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (CdnConfig.isCloudEnabled) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<int>(
                        future: SongDownloadService.getCacheSizeBytes(),
                        builder: (context, snapshot) {
                          final size = snapshot.data ?? 0;
                          return Text(
                            'Cached: ${_formatBytes(size)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _clearStorageAndReset(context),
                        child: const Text('Clear storage and reset'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
