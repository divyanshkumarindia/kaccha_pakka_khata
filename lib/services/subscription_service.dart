import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Central service that wraps a [SubscriptionRepository] and provides
/// convenient guard methods for the entire app.
///
/// Usage:
/// ```dart
/// final sub = Provider.of<SubscriptionService>(context, listen: false);
/// if (sub.canAccess(Feature.darkMode)) { ... }
/// ```
class SubscriptionService extends ChangeNotifier {
  final SubscriptionRepository _repository;
  SubscriptionPlan _currentPlan = SubscriptionPlan.free;
  bool _isTrialActive = false;
  DateTime? _expirationDate;
  StreamSubscription<SubscriptionPlan>? _planSubscription;

  SubscriptionService(this._repository);

  // ─── Getters ───────────────────────────────────────────────

  SubscriptionPlan get currentPlan => _currentPlan;
  bool get isTrialActive => _isTrialActive;
  DateTime? get expirationDate => _expirationDate;

  bool get isFree => _currentPlan == SubscriptionPlan.free;
  bool get isPro => _currentPlan.isAtLeast(SubscriptionPlan.pro);
  bool get isPremium => _currentPlan == SubscriptionPlan.premium;

  int get maxKhatas => PlanLimits.maxKhatas(_currentPlan);
  int get maxSavedReports => PlanLimits.maxSavedReports(_currentPlan);
  int get reportHistoryDays => PlanLimits.reportHistoryDays(_currentPlan);

  // ─── Core Guard Method ─────────────────────────────────────

  /// Returns true if the user's current plan allows access to [feature].
  bool canAccess(Feature feature) {
    final required = featureMinimumPlan[feature];
    if (required == null) return true; // Unknown feature → allow
    return _currentPlan.isAtLeast(required);
  }

  /// Returns the minimum plan name needed for a given feature.
  String requiredPlanName(Feature feature) {
    final required = featureMinimumPlan[feature] ?? SubscriptionPlan.free;
    switch (required) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.premium:
        return 'Premium';
    }
  }

  // ─── Countable Limits ──────────────────────────────────────

  /// Whether the user can create another khata given [currentCount].
  bool canCreateKhata(int currentCount) {
    return currentCount < maxKhatas;
  }

  /// Whether the user can save another report given [currentCount].
  bool canSaveReport(int currentCount) {
    return currentCount < maxSavedReports;
  }

  // ─── Lifecycle ─────────────────────────────────────────────

  /// Initialize the service: fetch current plan and listen for changes.
  Future<void> init() async {
    try {
      _currentPlan = await _repository.getCurrentPlan();
      _isTrialActive = await _repository.isTrialActive();
      _expirationDate = await _repository.getExpirationDate();
    } catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService init error: $e');
      _currentPlan = SubscriptionPlan.free;
    }

    // Listen for live plan updates (purchase, renewal, expiry)
    _planSubscription = _repository.planChanges.listen((plan) {
      if (_currentPlan != plan) {
        _currentPlan = plan;
        notifyListeners();
      }
    });

    notifyListeners();
  }

  /// Restore purchases (e.g. after reinstall).
  Future<void> restorePurchases() async {
    try {
      _currentPlan = await _repository.restorePurchases();
      _isTrialActive = await _repository.isTrialActive();
      _expirationDate = await _repository.getExpirationDate();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Restore purchases error: $e');
    }
  }

  /// Link the subscription state to a specific user.
  Future<void> loginUser(String userId) async {
    await _repository.loginUser(userId);
    // Refresh state after login
    await init();
  }

  /// Disconnect user from subscription provider.
  Future<void> logoutUser() async {
    await _repository.logoutUser();
    _currentPlan = SubscriptionPlan.free;
    _isTrialActive = false;
    _expirationDate = null;
    notifyListeners();
  }

  // ─── UI Helpers ────────────────────────────────────────────

  /// Shows a feature gate dialog when a user tries to access a locked feature.
  /// Returns true if the user upgraded (so the caller can retry the action).
  ///
  /// This is a placeholder that will be replaced with the beautiful paywall
  /// in Phase 3. For now it shows a simple informational dialog.
  static Future<bool> showFeatureGate(
      BuildContext context, Feature feature) async {
    final featureName = featureDisplayName[feature] ?? 'This feature';
    final requiredPlan = featureMinimumPlan[feature] ?? SubscriptionPlan.pro;
    final planName = requiredPlan == SubscriptionPlan.premium ? 'Premium' : 'Pro';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF6366F1), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$planName Feature',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$featureName is available on the $planName plan.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upgrade to $planName to unlock this and many more features!',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              // TODO: Phase 3 — Navigate to Paywall screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Upgrade to $planName'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  void dispose() {
    _planSubscription?.cancel();
    super.dispose();
  }
}
