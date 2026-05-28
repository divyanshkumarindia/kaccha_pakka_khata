import '../models/subscription.dart';

/// Abstract interface for subscription data access.
///
/// This follows the Repository Pattern so the app logic is completely
/// decoupled from the payment provider (RevenueCat, Stripe, etc.).
/// Swap implementations by changing a single line in main.dart.
abstract class SubscriptionRepository {
  /// Get the user's current effective subscription plan.
  Future<SubscriptionPlan> getCurrentPlan();

  /// Stream of plan changes (e.g. when a purchase completes or expires).
  Stream<SubscriptionPlan> get planChanges;

  /// Whether the user is currently on a free trial.
  Future<bool> isTrialActive();

  /// When the current subscription or trial expires. Null if free or lifetime.
  Future<DateTime?> getExpirationDate();

  /// Attempt to restore previous purchases (useful after reinstall).
  Future<SubscriptionPlan> restorePurchases();

  /// Attempt to purchase a specific plan.
  Future<SubscriptionPlan> purchasePlan(SubscriptionPlan plan);

  /// Log in the subscription provider with a user ID so purchases are
  /// tied to the correct account.
  Future<void> loginUser(String userId);

  /// Log out the current user from the subscription provider.
  Future<void> logoutUser();
}
