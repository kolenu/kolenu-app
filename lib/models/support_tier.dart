/// Support tier for "Support Kolenu" IAP.
class SupportTier {
  const SupportTier({
    required this.id,
    required this.label,
    required this.description,
    required this.amount,
    required this.ctaLabel,
  });

  /// Product ID for App Store Connect / Play Console.
  final String id;

  /// Display label (e.g. "Friend of Kolenu").
  final String label;

  /// Short description / tooltip.
  final String description;

  /// Display amount (e.g. 5, 10, 18, 48).
  final int amount;

  /// CTA button label (e.g. "Become a Friend").
  final String ctaLabel;

  /// All four tiers per design doc.
  static const List<SupportTier> tiers = [
    SupportTier(
      id: 'kolenu_friend_5',
      label: 'Friend of Kolenu',
      description: 'Help us keep Hebrew audio lessons free and high-quality.',
      amount: 5,
      ctaLabel: 'Become a Friend',
    ),
    SupportTier(
      id: 'kolenu_supporter_10',
      label: 'Kolenu Supporter',
      description: 'Support ongoing recordings and app improvements.',
      amount: 10,
      ctaLabel: 'Become a Supporter',
    ),
    SupportTier(
      id: 'kolenu_champion_18',
      label: 'Kolenu Champion',
      description:
          'Your generosity helps us grow our library of Hebrew songs and prayers.',
      amount: 18,
      ctaLabel: 'Become a Champion',
    ),
    SupportTier(
      id: 'kolenu_patron_48',
      label: 'Kolenu Patron / Big Sponsor',
      description:
          'Make a big impact! Your support helps us expand and record more content.',
      amount: 48,
      ctaLabel: 'Become a Patron',
    ),
  ];

  static List<String> get productIds =>
      tiers.map((t) => t.id).toList();
}
