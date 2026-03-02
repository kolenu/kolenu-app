import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/support_tier.dart';

/// Handles in-app purchases for Support Kolenu tiers.
/// Requires Apple Developer account + App Store Connect setup for real purchases.
class SupportPurchaseService {
  SupportPurchaseService._();
  static final SupportPurchaseService instance = SupportPurchaseService._();

  static const String _keyHasSupported = 'kolenu_has_supported';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available = false;
  bool get isAvailable => _available;

  Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  ProductDetails? productForTier(SupportTier tier) => _products[tier.id];

  /// Whether the user has ever completed a support purchase.
  Future<bool> hasSupported() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSupported) ?? false;
  }

  /// Initialize: check availability, load products, listen to purchases.
  Future<void> initialize({
    required void Function(List<PurchaseDetails>) onPurchaseUpdate,
  }) async {
    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint(
        'SupportPurchaseService: IAP not available (simulator? no store?)',
      );
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      onPurchaseUpdate,
      onError: (e) =>
          debugPrint('SupportPurchaseService purchaseStream error: $e'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!_available) return;
    try {
      final response = await _iap.queryProductDetails(
        SupportTier.productIds.toSet(),
      );
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          'SupportPurchaseService: products not found: ${response.notFoundIDs}',
        );
      }
      if (response.productDetails.isNotEmpty) {
        _products = {for (final p in response.productDetails) p.id: p};
      }
    } catch (e) {
      debugPrint('SupportPurchaseService: loadProducts error: $e');
    }
  }

  /// Start a purchase for the given tier.
  /// Returns true if the purchase was initiated (user will see native sheet).
  Future<bool> purchase(SupportTier tier) async {
    if (!_available) return false;
    final product = _products[tier.id];
    if (product == null) {
      debugPrint('SupportPurchaseService: product ${tier.id} not loaded');
      return false;
    }
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      return await _iap.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('SupportPurchaseService: purchase error: $e');
      return false;
    }
  }

  /// Mark that the user has supported (call after successful purchase).
  Future<void> markHasSupported() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSupported, true);
  }

  /// Complete a purchase (call when status is purchased/restored).
  Future<void> completePurchase(PurchaseDetails details) async {
    if (details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
      await markHasSupported();
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
