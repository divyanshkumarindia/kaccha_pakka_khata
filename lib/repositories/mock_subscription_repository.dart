import 'dart:async';
import '../models/subscription.dart';
import 'subscription_repository.dart';

/// A mock implementation of [SubscriptionRepository] for development & testing.
///
/// By default, returns [SubscriptionPlan.free]. Use [setMockPlan] to simulate
/// Pro or Premium during development to verify feature gates.
class MockSubscriptionRepository implements SubscriptionRepository {
  SubscriptionPlan _mockPlan = SubscriptionPlan.free;
  bool _mockTrialActive = false;
  DateTime? _mockExpiration;

  final StreamController<SubscriptionPlan> _planController =
      StreamController<SubscriptionPlan>.broadcast();

  /// Change the mock plan. Useful for dev testing via a hidden settings toggle.
  void setMockPlan(SubscriptionPlan plan) {
    _mockPlan = plan;
    _planController.add(plan);
  }

  /// Simulate trial state.
  void setMockTrialActive(bool active) => _mockTrialActive = active;

  /// Simulate expiration date.
  void setMockExpiration(DateTime? date) => _mockExpiration = date;

  @override
  Future<SubscriptionPlan> getCurrentPlan() async => _mockPlan;

  @override
  Stream<SubscriptionPlan> get planChanges => _planController.stream;

  @override
  Future<bool> isTrialActive() async => _mockTrialActive;

  @override
  Future<DateTime?> getExpirationDate() async => _mockExpiration;

  @override
  Future<SubscriptionPlan> restorePurchases() async => _mockPlan;

  @override
  Future<SubscriptionPlan> purchasePlan(SubscriptionPlan plan) async {
    setMockPlan(plan);
    return plan;
  }

  @override
  Future<SubscriptionPlan> purchaseProduct(String productId) async {
    final plan = productId.contains('pro') ? SubscriptionPlan.pro : SubscriptionPlan.premium;
    setMockPlan(plan);
    return plan;
  }

  @override
  Future<void> loginUser(String userId) async {
    // No-op for mock
  }

  @override
  Future<void> logoutUser() async {
    // No-op for mock
  }

  void dispose() {
    _planController.close();
  }
}
