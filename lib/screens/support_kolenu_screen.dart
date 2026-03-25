import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal.dart';
import '../models/support_tier.dart';
import '../services/support_purchase_service.dart';

/// Screen for "Support Kolenu" IAP.
/// One card: pick a tier (chips), then a single purchase button.
/// Amounts are fixed App Store products — arbitrary custom amounts are not supported for IAP.
class SupportKolenuScreen extends StatefulWidget {
  const SupportKolenuScreen({super.key});

  @override
  State<SupportKolenuScreen> createState() => _SupportKolenuScreenState();
}

class _SupportKolenuScreenState extends State<SupportKolenuScreen> {
  final SupportPurchaseService _service = SupportPurchaseService.instance;
  bool _initialized = false;
  bool _purchasing = false;
  String? _error;

  /// Default: Champion tier (store price is often US \$17.99 for the \$18 tier).
  SupportTier _selectedTier = SupportTier.tiers[2];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.initialize(onPurchaseUpdate: _onPurchaseUpdate);
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> details) {
    for (final d in details) {
      switch (d.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _purchasing = true);
          break;
        case PurchaseStatus.error:
          if (mounted) {
            setState(() {
              _purchasing = false;
              _error = d.error?.message ?? 'Purchase failed';
            });
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _service.completePurchase(d);
          if (mounted) {
            setState(() => _purchasing = false);
            _showThankYou();
          }
          break;
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _purchasing = false);
          break;
      }
    }
  }

  void _showThankYou() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for supporting Hebrew learning! ❤️'),
        duration: Duration(seconds: 4),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _onTierTap(SupportTier tier) async {
    setState(() => _error = null);
    if (_purchasing) return;

    if (!_service.isAvailable) {
      setState(
        () => _error = 'In-app purchases are not available on this device.',
      );
      return;
    }

    final product = _service.productForTier(tier);
    if (product == null) {
      setState(
        () => _error =
            'Products not loaded. Ensure IAP is configured in App Store Connect.',
      );
      return;
    }

    final ok = await _service.purchase(tier);
    if (!ok && mounted) {
      setState(() => _error = 'Could not start purchase. Please try again.');
    }
  }

  Future<void> _openCustomAmountEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'hello@kolenu.net',
      queryParameters: <String, String>{
        'subject': 'Kolenu support — custom amount',
      },
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
      appBar: AppBar(title: const Text('Support Kolenu ❤️'), centerTitle: true),
      body: SafeArea(
        child: _initialized
            ? _buildContent(theme, colorScheme)
            : _buildLoading(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thank you for supporting Hebrew learning! ❤️',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your support matters. Every amount helps us keep Hebrew prayers and '
            'songs accessible, record high-quality audio, and improve the app for everyone.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (!_service.isAvailable)
            _buildUnavailableBanner(theme, colorScheme),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildTierSelector(theme, colorScheme),
          const SizedBox(height: 16),
          Text(
            'Support amounts are fixed by the App Store. '
            'Pick the tier that fits you best.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _openCustomAmountEmail,
            child: const Text('Discuss another amount by email'),
          ),
          const SizedBox(height: 16),
          Text(
            LegalText.supportDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableBanner(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'In-app purchases not available',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Purchases require a real device and an app configured in App Store Connect. '
              'See docs/SUPPORT_KOLENU_IAP_DESIGN.md for setup.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierSelector(ThemeData theme, ColorScheme colorScheme) {
    final product = _service.productForTier(_selectedTier);
    final price = product?.price ?? '\$${_selectedTier.amount}';
    final canPurchase = _service.isAvailable && !_purchasing;
    final canBuySelected = canPurchase && product != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose support amount',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select one tier, then confirm with Apple.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final SupportTier tier in SupportTier.tiers)
                  ChoiceChip(
                    label: Text(_chipLabel(tier)),
                    selected: tier == _selectedTier,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: tier == _selectedTier
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.45),
                      width: tier == _selectedTier ? 2 : 1,
                    ),
                    onSelected: _purchasing
                        ? null
                        : (bool selected) {
                            if (selected) {
                              setState(() => _selectedTier = tier);
                            }
                          },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Support Kolenu for $price',
              button: true,
              child: FilledButton(
                onPressed: canBuySelected
                    ? () => _onTierTap(_selectedTier)
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Support Kolenu ($price)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip label: localized store price when loaded, else fallback `$amount`.
  String _chipLabel(SupportTier tier) {
    final product = _service.productForTier(tier);
    return product?.price ?? '\$${tier.amount}';
  }
}
