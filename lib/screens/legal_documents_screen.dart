import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalDocumentsScreen extends StatelessWidget {
  const LegalDocumentsScreen({super.key});

  Future<void> _sendIPViolationReport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'info@digimint.ca',
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
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  content,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
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
      appBar: AppBar(
        title: const Text('Legal Documents'),
        centerTitle: true,
      ),
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
                  'Kolenu™ Usage Disclaimer',
                  'Kolenu provides Jewish prayer content, melodies, and guidance for personal, educational, and religious study purposes. While we aim for accuracy, '
                  'Kolenu does not guarantee completeness, correctness, or suitability for any particular practice or ritual.\n\n'
                  'Users should not rely solely on Kolenu for religious decisions or guidance. Always consult a qualified rabbi, cantor, or teacher for personal or communal matters.\n\n'
                  'Kolenu is not a substitute for professional advice in health, safety, or legal matters. Use responsibly.\n\n'
                  'By using Kolenu, you acknowledge that the app and its content are provided "as is", and the developers assume no liability for any actions or decisions resulting from its use.',
                ),
              ),
              const SizedBox(height: 12),
              // Copyright & Takedown
              _buildDocumentTile(
                context,
                icon: Icons.copyright_outlined,
                title: 'Copyright & IP Protection',
                description: 'Information about copyright ownership and reporting violations',
                onTap: () => _showDialog(
                  context,
                  'Copyright & IP Protection',
                  'All original audio recordings and the "Kolenu" brand name are Copyright © 2026 DigiMint Inc. All Rights Reserved.\n\n'
                  'REPORTING IP VIOLATIONS:\n'
                  'We respect intellectual property rights. If you believe your work is used without permission in this app, please report it immediately.\n\n'
                  'Email: info@digimint.ca\n'
                  'Subject: IP Violation Report\n\n'
                  'Please include:\n'
                  '• Clear description of the content you believe is infringing\n'
                  '• Evidence of your ownership or rights\n'
                  '• Specific location(s) in the app where content appears\n'
                  '• Your preferred resolution (removal, attribution, licensing, etc.)\n\n'
                  'We will promptly investigate and take immediate action if the violation is confirmed.',
                ),
              ),
              const SizedBox(height: 12),
              // Report IP Violation Button
              FilledButton.tonal(
                onPressed: _sendIPViolationReport,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flag_outlined, color: colorScheme.onSecondaryContainer),
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
                  'Privacy Policy',
                  'Kolenu does NOT collect personal information.\n\n'
                  'We do NOT collect:\n'
                  '• Name, email, or phone number\n'
                  '• Account credentials\n'
                  '• Location data\n'
                  '• Contacts, photos, or user-generated content\n\n'
                  'No registration or login is required.\n\n'
                  'AUTOMATIC INFORMATION:\n'
                  'When downloading audio or text, standard network information (e.g., IP addresses and HTTP headers) may be processed by our content delivery provider (Cloudflare) to deliver files efficiently. This information is NOT linked to any user and is NOT stored by Kolenu.\n\n'
                  'The app does NOT collect device identifiers, advertising identifiers (IDFA), or other unique IDs.\n\n'
                  'IN-APP PURCHASES:\n'
                  'Optional subscriptions are handled entirely by Apple. Kolenu does NOT receive or store payment information. Please see Apple\'s privacy policy for payment details.',
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
                  'Important Notice',
                  'This repository contains ONLY the application source code.\n\n'
                  'The following are NOT included and are NOT licensed under BSL 1.2:\n'
                  '• Prayer texts (Hebrew or translated)\n'
                  '• Audio recordings\n'
                  '• Nusach or accent variations\n'
                  '• Educational or liturgical content\n'
                  '• Licensed or proprietary religious material\n\n'
                  'All religious texts, audio recordings, and associated metadata used by the Kolenu app are proprietary and/or used under separate licenses and permissions.\n\n'
                  'TRADEMARK NOTICE:\n'
                  '"Kolenu" and the Kolenu logo are trademarks of DigiMint Inc. This license does not grant permission to use the name, logo, or branding for derivative works or distributions without permission.',
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
                  'License (BSL 1.2)',
                  'The application source code is licensed under the Business Source License 1.2 (BSL 1.2).\n\n'
                  'ADDITIONAL USE GRANT:\n'
                  '• Non-commercial use allowed\n'
                  '• No commercial prayer / music streaming apps\n'
                  '• No SaaS or subscription-based religious audio services\n\n'
                  'Change Date: 2030-02-17\n\n'
                  'You are free to use, modify, and distribute the code in accordance with the BSL 1.2 license.\n\n'
                  'After the Change Date, this code will be available under more permissive terms.',
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
