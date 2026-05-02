import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';
import '../widgets/paywall_dialog.dart';

/// Central service that wraps a [SubscriptionRepository] and provides
/// convenient guard methods for the entire app.
///
/// Usage:
/// ```dart
/// final sub = Provider.of<SubscriptionService>(context, listen: false);
/// if (sub.canAccess(Feature.downloadPdfExcel)) { enableExport(); }
/// else { SubscriptionService.showFeatureGate(context, Feature.downloadPdfExcel); }
/// ```
class SubscriptionService extends ChangeNotifier {
  final SubscriptionRepository _repository;
  SubscriptionPlan _currentPlan = SubscriptionPlan.free;
  bool _isTrialActive = false;
  DateTime? _expirationDate;
  bool _isInitialized = false;
  StreamSubscription<SubscriptionPlan>? _planSubscription;

  SubscriptionService(this._repository);

  // ─── Getters ───────────────────────────────────────────────

  SubscriptionPlan get currentPlan => _currentPlan;
  bool get isTrialActive => _isTrialActive;
  DateTime? get expirationDate => _expirationDate;
  bool get isInitialized => _isInitialized;

  bool get isFree => _currentPlan == SubscriptionPlan.free;
  bool get isPro => _currentPlan == SubscriptionPlan.pro;
  bool get isPremium => _currentPlan == SubscriptionPlan.premium;

  int get maxKhatas => PlanLimits.maxKhatas(_currentPlan);
  int get maxSavedReports => PlanLimits.maxSavedReports(_currentPlan);
  int get reportHistoryDays => PlanLimits.reportHistoryDays(_currentPlan);

  /// Human-readable name for the current plan.
  String get currentPlanDisplayName {
    switch (_currentPlan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.premium:
        return 'Premium';
    }
  }

  /// FOR DEBUGGING ONLY: Manually override the current plan
  void debugSetPlan(SubscriptionPlan newPlan) {
    _currentPlan = newPlan;
    notifyListeners();
  }

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
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService init error: $e');
      _currentPlan = SubscriptionPlan.free;
      _isInitialized = true; // Mark as initialized even on error (fail-safe to Free)
    }

    // Cancel any previous listener before creating a new one (prevents duplicates)
    await _planSubscription?.cancel();

    // Listen for live plan updates (purchase, renewal, expiry)
    _planSubscription = _repository.planChanges.listen((plan) {
      if (_currentPlan != plan) {
        _currentPlan = plan;
        // Refresh trial + expiration info when plan changes
        _repository.isTrialActive().then((v) => _isTrialActive = v);
        _repository.getExpirationDate().then((v) => _expirationDate = v);
        notifyListeners();
      }
    });

    notifyListeners();
  }

  /// Restore purchases (e.g. after reinstall or app reset).
  Future<SubscriptionPlan> restorePurchases() async {
    try {
      _currentPlan = await _repository.restorePurchases();
      _isTrialActive = await _repository.isTrialActive();
      _expirationDate = await _repository.getExpirationDate();
      notifyListeners();
      return _currentPlan;
    } catch (e) {
      if (kDebugMode) debugPrint('Restore purchases error: $e');
      return _currentPlan;
    }
  }

  /// Link the subscription state to a specific user.
  Future<void> loginUser(String userId) async {
    await _repository.loginUser(userId);
    await init(); // Refresh state after login
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
  /// If the user taps "Upgrade", it presents the RevenueCat Paywall.
  /// Returns true if the user successfully upgraded.
  static Future<bool> showFeatureGate(
      BuildContext context, Feature feature) async {
    final featureName = featureDisplayName[feature] ?? 'This feature';
    final requiredPlan = featureMinimumPlan[feature] ?? SubscriptionPlan.pro;
    final planName =
        requiredPlan == SubscriptionPlan.premium ? 'Premium' : 'Pro';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? const Color(0xFF1F2937) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$planName Feature',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
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
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.12),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Color(0xFFF59E0B), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Start your 14-day free trial of $planName today!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop(true);
              },
              icon: const Icon(Icons.rocket_launch, size: 18),
              label: Text('Upgrade to $planName'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );

    // If user tapped "Upgrade", show our custom paywall
    if (result == true && context.mounted) {
      return await showPaywall(context);
    }

    return false;
  }

  /// Opens the custom paywall dialog showing all 3 plans.
  /// Useful for the "Upgrade" button in settings / navigation drawer.
  static Future<bool> showPaywall(BuildContext context) async {
    try {
      return await PaywallDialog.show(context);
    } catch (e) {
      if (kDebugMode) debugPrint('Paywall error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _planSubscription?.cancel();
    super.dispose();
  }
}
