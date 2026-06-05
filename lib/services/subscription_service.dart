import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String? _activeProductId;
  int? _activeDurationDays;
  bool _isInitialized = false;
  StreamSubscription<SubscriptionPlan>? _planSubscription;

  SubscriptionService(this._repository);

  // ─── Getters ───────────────────────────────────────────────

  SubscriptionPlan get currentPlan => _currentPlan;
  bool get isTrialActive => _isTrialActive;
  DateTime? get expirationDate => _expirationDate;
  String? get activeProductId => _activeProductId;
  int? get activeDurationDays => _activeDurationDays;
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
  Future<void> _initImpl() async {
    _currentPlan = await _repository.getCurrentPlan();
    _isTrialActive = await _repository.isTrialActive();
    _expirationDate = await _repository.getExpirationDate();
    _activeProductId = await _repository.getActiveProductId();
    _activeDurationDays = null;
    await _checkDatabaseOverride();
  }

  /// Initialize the service: fetch current plan and listen for changes.
  Future<void> init() async {
    try {
      await _initImpl();
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService init error: $e');
      _currentPlan = SubscriptionPlan.free;
      _isInitialized = true; // Mark as initialized even on error (fail-safe to Free)
    }

    // Cancel any previous listener before creating a new one (prevents duplicates)
    await _planSubscription?.cancel();

    _planSubscription = _repository.planChanges.listen(
      (plan) async {
        _currentPlan = plan;
        try {
          final activeTrial = await _repository.isTrialActive();
          final expDate = await _repository.getExpirationDate();
          final prodId = await _repository.getActiveProductId();
          _isTrialActive = activeTrial;
          _expirationDate = expDate;
          _activeProductId = prodId;
          _activeDurationDays = null;
          await _checkDatabaseOverride();
        } catch (e) {
          if (kDebugMode) debugPrint('SubscriptionService plan stream refresh error: $e');
        }
        notifyListeners();
      },
      onError: (error, stackTrace) {
        if (kDebugMode) debugPrint('❌ SubscriptionService planChanges stream error: $error');
      },
    );

    notifyListeners();
  }

  Future<void> _checkDatabaseOverride() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final response = await client
            .from('user_data')
            .select('data')
            .eq('user_id', user.id)
            .maybeSingle();

        final isSuperAdmin = user.email?.toLowerCase() == 'divyanshkumarindia@gmail.com';
        Map<String, dynamic>? data;
        if (response != null && response['data'] != null) {
          data = Map<String, dynamic>.from(response['data'] as Map);
        }

        if (isSuperAdmin && (data == null || !data.containsKey('granted_plan'))) {
          // Default super admin to premium lifetime
          final lifetimeUntil = DateTime.now().add(const Duration(days: 99999)).toIso8601String();
          final updatedData = data != null ? Map<String, dynamic>.from(data) : <String, dynamic>{};
          updatedData['granted_plan'] = 'premium';
          updatedData['granted_until'] = lifetimeUntil;
          updatedData['granted_duration_days'] = 99999;
          updatedData['is_admin'] = true;

          await client.from('user_data').upsert({
            'user_id': user.id,
            'data': updatedData,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');

          _currentPlan = SubscriptionPlan.premium;
          _expirationDate = DateTime.parse(lifetimeUntil);
          _activeDurationDays = 99999;
          return;
        }

        if (data != null) {
          final grantedPlanStr = data['granted_plan'] as String?;
          final grantedUntilStr = data['granted_until'] as String?;
          final grantedDurationDays = data['granted_duration_days'] as int?;

          if (grantedPlanStr != null && grantedUntilStr != null) {
            final grantedUntil = DateTime.parse(grantedUntilStr);
            if (DateTime.now().isBefore(grantedUntil)) {
              int? activeDays = grantedDurationDays;
              if (activeDays == null) {
                final daysLeft = grantedUntil.difference(DateTime.now()).inDays;
                if (daysLeft > 0) {
                  if (daysLeft > 10000) {
                    activeDays = 99999;
                  } else if (daysLeft <= 7) {
                    activeDays = 7;
                  } else if (daysLeft <= 30) {
                    activeDays = 30;
                  } else if (daysLeft <= 90) {
                    activeDays = 90;
                  } else if (daysLeft <= 365) {
                    activeDays = 365;
                  } else if (daysLeft <= 730) {
                    activeDays = 730;
                  } else if (daysLeft <= 1095) {
                    activeDays = 1095;
                  } else if (daysLeft <= 1825) {
                    activeDays = 1825;
                  } else {
                    activeDays = 99999;
                  }
                }
              }
              if (grantedPlanStr == 'premium') {
                _currentPlan = SubscriptionPlan.premium;
                _expirationDate = grantedUntil;
                _activeDurationDays = activeDays;
              } else if (grantedPlanStr == 'pro') {
                _currentPlan = SubscriptionPlan.pro;
                _expirationDate = grantedUntil;
                _activeDurationDays = activeDays;
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking database override: $e');
    }
  }

  /// Redeems an in-app promo code in Supabase.
  /// Returns a Map containing:
  /// - `success`: bool
  /// - `message`: String
  /// - `plan`: SubscriptionPlan?
  Future<Map<String, dynamic>> redeemPromoCode(String code) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'You must be logged in to redeem a code.'};
    }

    final sanitizedCode = code.trim().toUpperCase();

    try {
      // 1. Fetch promo code details
      final promo = await client
          .from('promo_codes')
          .select()
          .eq('code', sanitizedCode)
          .maybeSingle();

      if (promo == null) {
        return {'success': false, 'message': 'Invalid promo code. This code does not exist.'};
      }

      final planStr = promo['plan'] as String;
      final durationDays = promo['duration_days'] as int;
      final maxUses = promo['max_uses'] as int;
      final usesCount = promo['uses_count'] as int;
      final isActive = promo['is_active'] as bool? ?? true;

      // 2. Check usage limit and active status
      if (!isActive || usesCount >= maxUses) {
        return {'success': false, 'message': 'This promo code has expired or reached its maximum usage limit.'};
      }

      // 3. Check if user already redeemed this code
      final existingRedemption = await client
          .from('user_promo_redemptions')
          .select()
          .eq('user_id', user.id)
          .eq('code', sanitizedCode)
          .maybeSingle();

      if (existingRedemption != null) {
        return {'success': false, 'message': 'You have already redeemed this promo code.'};
      }

      // 4. Perform the redemption
      await client.from('user_promo_redemptions').insert({
        'user_id': user.id,
        'code': sanitizedCode,
      });

      await client
          .from('promo_codes')
          .update({'uses_count': usesCount + 1})
          .eq('code', sanitizedCode);

      final grantedPlan = planStr == 'premium' ? SubscriptionPlan.premium : SubscriptionPlan.pro;
      final grantedUntil = DateTime.now().add(Duration(days: durationDays));

      final configResponse = await client
          .from('user_data')
          .select('data')
          .eq('user_id', user.id)
          .maybeSingle();

      final currentData = configResponse != null && configResponse['data'] != null
          ? Map<String, dynamic>.from(configResponse['data'] as Map)
          : <String, dynamic>{};

      currentData['granted_plan'] = planStr;
      currentData['granted_until'] = grantedUntil.toIso8601String();
      currentData['granted_duration_days'] = durationDays;

      await client.from('user_data').upsert({
        'user_id': user.id,
        'data': currentData,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      _currentPlan = grantedPlan;
      _expirationDate = grantedUntil;
      _activeDurationDays = durationDays;
      _activeProductId = null;
      notifyListeners();

      return {
        'success': true,
        'message': 'Code redeemed successfully!',
        'plan': grantedPlan,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('Promo redemption error: $e');
      return {'success': false, 'message': 'Redemption failed: ${e.toString()}'};
    }
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

  /// Purchase a plan.
  Future<SubscriptionPlan> purchasePlan(SubscriptionPlan plan) async {
    try {
      final newPlan = await _repository.purchasePlan(plan);
      if (_currentPlan != newPlan) {
        _currentPlan = newPlan;
        _isTrialActive = await _repository.isTrialActive();
        _expirationDate = await _repository.getExpirationDate();
        notifyListeners();
      }
      return _currentPlan;
    } catch (e) {
      if (kDebugMode) debugPrint('Purchase error: $e');
      return _currentPlan;
    }
  }

  /// Purchase a specific product.
  Future<SubscriptionPlan> purchaseProduct(String productId) async {
    try {
      final newPlan = await _repository.purchaseProduct(productId);
      if (_currentPlan != newPlan) {
        _currentPlan = newPlan;
        _isTrialActive = await _repository.isTrialActive();
        _expirationDate = await _repository.getExpirationDate();
        notifyListeners();
      }
      return _currentPlan;
    } catch (e) {
      if (kDebugMode) debugPrint('Purchase product error: $e');
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
              onPressed: () {
                Navigator.of(ctx).pop(); // Close feature gate dialog
                // Show the paywall
                showDialog(
                  context: context,
                  builder: (context) => const PaywallDialog(),
                );
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
