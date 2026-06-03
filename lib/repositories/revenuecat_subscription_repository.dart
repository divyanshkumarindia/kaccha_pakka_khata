import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/subscription.dart';
import 'subscription_repository.dart';

/// RevenueCat entitlement identifiers — must match exactly what's configured
/// in the RevenueCat dashboard.
class _Entitlements {
  static const String pro = 'Kaccha Pakka Khata Pro';
  static const String premium = 'Kaccha Pakka Khata Premium';
}

/// Real implementation of [SubscriptionRepository] backed by RevenueCat.
///
/// Call [initialize] once at app startup before using any other methods.
class RevenueCatSubscriptionRepository implements SubscriptionRepository {


  final StreamController<SubscriptionPlan> _planController =
      StreamController<SubscriptionPlan>.broadcast();

  bool _isInitialized = false;

  /// Initialize the RevenueCat SDK. Must be called once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Skip on web — RevenueCat requires native mobile platform
      if (kIsWeb) {
        if (kDebugMode) {
          debugPrint('⚠️ RevenueCat: Web platform not supported, skipping');
        }
        return;
      }

      String apiKey;
      if (Platform.isIOS) {
        apiKey = dotenv.env['REVENUECAT_IOS_KEY'] ?? '';
      } else if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUECAT_ANDROID_KEY'] ?? '';
      } else {
        // Desktop / Web — fall back to Android key or skip
        if (kDebugMode) {
          debugPrint('⚠️ RevenueCat: Unsupported platform, skipping init');
        }
        return;
      }

      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      // Listen for customer info changes (purchase, renewal, expiry, etc.)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        final plan = _planFromCustomerInfo(customerInfo);
        _planController.add(plan);
      });

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ RevenueCat initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ RevenueCat initialization error: $e');
      }
    }
  }

  /// Derives the effective [SubscriptionPlan] from RevenueCat's CustomerInfo.
  ///
  /// Premium entitlement takes priority. If a user has both, they're Premium.
  SubscriptionPlan _planFromCustomerInfo(CustomerInfo info) {
    final activeEntitlements = info.entitlements.active;

    if (activeEntitlements.containsKey(_Entitlements.premium)) {
      return SubscriptionPlan.premium;
    }
    if (activeEntitlements.containsKey(_Entitlements.pro)) {
      return SubscriptionPlan.pro;
    }
    return SubscriptionPlan.free;
  }

  @override
  Future<SubscriptionPlan> getCurrentPlan() async {
    if (!_isInitialized) return SubscriptionPlan.free;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _planFromCustomerInfo(customerInfo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error fetching customer info: $e');
      }
      return SubscriptionPlan.free; // Fail-safe: default to free
    }
  }

  @override
  Stream<SubscriptionPlan> get planChanges => _planController.stream;

  @override
  Future<bool> isTrialActive() async {
    if (!_isInitialized) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final activeEntitlements = customerInfo.entitlements.active;

      // Check if any active entitlement is in a trial period
      for (final entitlement in activeEntitlements.values) {
        if (entitlement.periodType == PeriodType.trial) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<DateTime?> getExpirationDate() async {
    if (!_isInitialized) return null;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final activeEntitlements = customerInfo.entitlements.active;

      // Return the latest expiration date among active entitlements
      DateTime? latest;
      for (final entitlement in activeEntitlements.values) {
        if (entitlement.expirationDate != null) {
          final expDate = DateTime.parse(entitlement.expirationDate!);
          if (latest == null || expDate.isAfter(latest)) {
            latest = expDate;
          }
        }
      }
      return latest;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> getActiveProductId() async {
    if (!_isInitialized) return null;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final activeEntitlements = customerInfo.entitlements.active;

      if (activeEntitlements.isNotEmpty) {
        return activeEntitlements.values.first.productIdentifier;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<SubscriptionPlan> restorePurchases() async {
    if (!_isInitialized) return SubscriptionPlan.free;

    try {
      final customerInfo = await Purchases.restorePurchases();
      final plan = _planFromCustomerInfo(customerInfo);
      _planController.add(plan);
      return plan;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error restoring purchases: $e');
      }
      return SubscriptionPlan.free;
    }
  }

  @override
  Future<SubscriptionPlan> purchasePlan(SubscriptionPlan plan) async {
    if (!_isInitialized) return SubscriptionPlan.free;

    try {
      String productId;
      if (plan == SubscriptionPlan.pro) {
        productId = 'pro_monthly:pro-monthly-bp';
      } else if (plan == SubscriptionPlan.premium) {
        productId = 'premium_monthly:premium-monthly-bp';
      } else {
        return SubscriptionPlan.free;
      }

      // 1. Fetch the product from RevenueCat
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) {
        if (kDebugMode) debugPrint('❌ Product $productId not found in RevenueCat');
        throw Exception('Product not found');
      }

      // 2. Trigger the native Google Play purchase flow
      // ignore: deprecated_member_use
      final purchaseResult = await Purchases.purchaseStoreProduct(products.first);
      
      // 3. Update state based on the new purchase
      final newPlan = _planFromCustomerInfo(purchaseResult.customerInfo);
      _planController.add(newPlan);
      return newPlan;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error purchasing plan: $e');
      }
      // If the user cancelled the purchase, it will throw an error, which we catch here
      return SubscriptionPlan.free;
    }
  }

  @override
  Future<SubscriptionPlan> purchaseProduct(String productId) async {
    if (!_isInitialized) return SubscriptionPlan.free;

    try {
      // 1. Fetch the product from RevenueCat
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) {
        if (kDebugMode) debugPrint('❌ Product $productId not found in RevenueCat');
        throw Exception('Product not found');
      }

      // 2. Trigger the native Google Play purchase flow
      // ignore: deprecated_member_use
      final purchaseResult = await Purchases.purchaseStoreProduct(products.first);
      
      // 3. Update state based on the new purchase
      final newPlan = _planFromCustomerInfo(purchaseResult.customerInfo);
      _planController.add(newPlan);
      return newPlan;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error purchasing product $productId: $e');
      }
      return await getCurrentPlan();
    }
  }

  @override
  Future<void> loginUser(String userId) async {
    if (!_isInitialized) return;

    try {
      await Purchases.logIn(userId);
      if (kDebugMode) {
        debugPrint('✅ RevenueCat logged in user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ RevenueCat login error: $e');
      }
    }
  }

  @override
  Future<void> logoutUser() async {
    if (!_isInitialized) return;

    try {
      await Purchases.logOut();
      _planController.add(SubscriptionPlan.free);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ RevenueCat logout error: $e');
      }
    }
  }

  void dispose() {
    _planController.close();
  }
}
