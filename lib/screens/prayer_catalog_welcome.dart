import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/cdn_config.dart';
import '../services/broadcast_message_service.dart';
import '../services/offline_tip_service.dart';
import '../utils/url_validator.dart';

/// One-time tips and broadcast dialogs after the prayer catalog loads (cloud builds).
Future<void> runPrayerCatalogWelcomeFlow(BuildContext context) async {
  if (!CdnConfig.isCloudEnabled) return;

  final bool shown = await OfflineTipService.hasShownTip();
  if (!shown) {
    if (!context.mounted) return;
    await OfflineTipService.markTipShown();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tap a prayer to download it for offline listening. The pin icon shows which prayers are cached.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  final messages = await BroadcastMessageService.fetchMessagesToShow();
  if (!context.mounted || messages.isEmpty) return;
  for (final msg in messages) {
    if (!context.mounted) return;
    final bool hasSafeLink =
        msg.link != null && UrlValidator.isSafeToOpen(msg.link);
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(msg.title),
        content: SingleChildScrollView(child: Text(msg.body)),
        actions: [
          if (hasSafeLink)
            TextButton(
              onPressed: () async {
                final Uri uri = Uri.parse(msg.link!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Learn more'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
