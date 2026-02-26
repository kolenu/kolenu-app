import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal.dart';

class LegalDocumentsScreen extends StatelessWidget {
  const LegalDocumentsScreen({super.key});

  Future<void> _sendIPViolationReport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'info@kolenu.net',
      query: 'subject=IP Violation Report',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _showDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Text(
                  content,
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Legal Documents'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Kolenu Legal & Disclaimers',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Access all legal documents and disclaimers for Kolenu.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              // Usage Disclaimer
              _buildDocumentTile(
                context,
                icon: Icons.info_outlined,
                title: 'Usage Disclaimer',
                description: 'Important notice about using Kolenu responsibly',
                onTap: () => _showDialog(
                  context,
                  LegalText.usageDisclaimerTitle,
                  LegalText.usageDisclaimerContent,
                ),
              ),
              const SizedBox(height: 12),
              // Copyright & Takedown
              _buildDocumentTile(
                context,
                icon: Icons.copyright_outlined,
                title: 'Copyright & IP Protection',
                description:
                    'Information about copyright ownership and reporting violations',
                onTap: () => _showDialog(
                  context,
                  LegalText.copyrightIpTitle,
                  LegalText.copyrightIpContent,
                ),
              ),
              const SizedBox(height: 12),
              // Report IP Violation Button
              FilledButton.tonal(
                onPressed: _sendIPViolationReport,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Report IP Violation',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Privacy Policy
              _buildDocumentTile(
                context,
                icon: Icons.lock_outline,
                title: 'Privacy Policy',
                description: 'How we handle your data and privacy',
                onTap: () => _showDialog(
                  context,
                  LegalText.privacyPolicyTitle,
                  LegalText.privacyPolicyContent,
                ),
              ),
              const SizedBox(height: 12),
              // Terms of Service
              _buildDocumentTile(
                context,
                icon: Icons.gavel_outlined,
                title: 'Terms of Service',
                description: 'Terms that govern use of the Kolenu app',
                onTap: () => _showDialog(
                  context,
                  LegalText.termsOfServiceTitle,
                  LegalText.termsOfServiceContent,
                ),
              ),
              const SizedBox(height: 12),
              // Notice
              _buildDocumentTile(
                context,
                icon: Icons.description_outlined,
                title: 'Notice',
                description: 'Important notice regarding content and licensing',
                onTap: () => _showDialog(
                  context,
                  LegalText.importantNoticeTitle,
                  LegalText.importantNoticeContent,
                ),
              ),
              const SizedBox(height: 12),
              // License
              _buildDocumentTile(
                context,
                icon: Icons.article_outlined,
                title: 'License (BSL 1.2)',
                description: 'Business Source License 1.2 - App code licensing',
                onTap: () => _showDialog(
                  context,
                  LegalText.licenseTitle,
                  LegalText.licenseContent,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
