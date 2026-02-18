import 'package:flutter/material.dart';

import '../config/cdn_config.dart';
import '../services/cloud_index_service.dart';
import '../services/song_download_service.dart';
import '../services/terms_agreement_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearStorageAndReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear storage and reset?'),
        content: const Text(
          'Remove all downloaded songs and reset the welcome screen. Use when switching CDN versions or to test the first-launch flow. You can re-download songs after.',
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
      int count = 0;
      if (CdnConfig.isCloudEnabled) {
        count = await SongDownloadService.clearAllSongs();
        await CloudIndexService.clearCache();
      }
      await TermsAgreementService.clearAgreed();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Cleared $count song(s). Welcome screen will appear.'
                  : 'Reset complete. Welcome screen will appear.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
              'Storage',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Clear downloaded songs and reset the welcome screen. Use when switching CDN versions or to test the first-launch flow.',
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
