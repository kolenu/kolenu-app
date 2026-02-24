import 'package:flutter/material.dart';

import '../config/cdn_config.dart';
import '../services/cloud_index_service.dart';
import '../services/default_playlist_service.dart';
import 'playlist_screen.dart';
import '../services/font_size_preference_service.dart';
import '../services/orientation_preference_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final lock = await OrientationPreferenceService.getLockPortrait();
    final font = await FontSizePreferenceService.getOption();
    if (mounted) {
      setState(() {
        _lockPortrait = lock;
        _fontSize = font;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Playlist',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 32),
            Text(
              'Display',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 8),
            Text(
              'Text size',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            SegmentedButton<FontSizeOption>(
              segments: FontSizeOption.values
                  .map((o) => ButtonSegment(value: o, label: Text(o.label)))
                  .toList(),
              selected: {_fontSize},
              onSelectionChanged: (s) async {
                final v = s.first;
                setState(() => _fontSize = v);
                await FontSizePreferenceService.setOption(v);
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Offline',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download prayers to listen without internet. Tap a prayer to download it, then use it offline. The pin icon shows which prayers are cached.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Storage',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
            if (CdnConfig.isCloudEnabled)
              FutureBuilder<int>(
                future: SongDownloadService.getCacheSizeBytes(),
                builder: (context, snapshot) {
                  final size = snapshot.data ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Cached prayers: ${_formatBytes(size)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            Text(
              'Clear downloaded songs and reset the welcome screen. Use when switching CDN releases or to test the first-launch flow.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: () => _clearStorageAndReset(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
              ),
              child: const Text('Clear storage and reset'),
            ),
          ],
        ),
      ),
    );
  }
}
