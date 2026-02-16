import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/cdn_config.dart';
import '../services/cloud_index_service.dart';
import '../services/song_download_service.dart';
import '../widgets/kolenu_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _clearDownloads(BuildContext context) async {
    if (!CdnConfig.isCloudEnabled) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear downloaded songs?'),
        content: const Text(
          'Remove all downloaded songs. Use when switching CDN versions (e.g. dummy ↔ prod1) to fix decryption errors. You can re-download after.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final count = await SongDownloadService.clearAllSongs();
      await CloudIndexService.clearCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared $count song(s). Re-download to play.')),
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

  Future<void> _sendFeedback() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'ozwang.tech@gmail.com',
      query: 'subject=Kolenu App Feedback',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: KolenuLogo(size: 200),
              ),
              const SizedBox(height: 24),
              Text(
                'Our Voice, Our Prayers',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Learn Hebrew prayers with audio, word-by-word highlighting, and English translations. For teens and adults.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Text(
                'Feedback',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                label: 'Send feedback about the app',
                button: true,
                child: FilledButton.tonal(
                  onPressed: _sendFeedback,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.feedback_outlined, color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 12),
                      Text(
                        'Send Feedback',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (CdnConfig.isCloudEnabled) ...[
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () => _clearDownloads(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  ),
                  child: const Text('Clear downloaded songs'),
                ),
              ],
              const SizedBox(height: 40),
              Text(
                'Version 1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
