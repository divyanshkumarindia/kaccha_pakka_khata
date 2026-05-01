import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/subscription_service.dart';

/// A beautiful, animated paywall dialog showing all 3 subscription plans
/// with features and pricing. Opens as a full-screen modal bottom sheet.
class PaywallDialog extends StatefulWidget {
  const PaywallDialog({super.key});

  /// Show the paywall as a modal bottom sheet.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PaywallDialog(),
    );
    return result ?? false;
  }

  @override
  State<PaywallDialog> createState() => _PaywallDialogState();
}

class _PaywallDialogState extends State<PaywallDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  int _selectedPlanIndex = 1; // Default to Pro (middle plan)

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = Provider.of<SubscriptionService>(context, listen: false);
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  // Crown icon with glow
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upgrade Your Khata',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the plan that works best for your business',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Plan cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Plan selector cards
                    _buildPlanCard(
                      index: 0,
                      planName: 'Free',
                      price: '₹0',
                      period: 'forever',
                      icon: Icons.person_rounded,
                      gradStart: const Color(0xFF64748B),
                      gradEnd: const Color(0xFF475569),
                      features: [
                        _PlanFeature('2 Khatas', true),
                        _PlanFeature('30 Days Report History', true),
                        _PlanFeature('5 Saved Reports', true),
                        _PlanFeature('Dark Mode / Themes', true),
                        _PlanFeature('Hindi + English', true),
                        _PlanFeature('Download PDF / Excel', false),
                        _PlanFeature('Cloud Backup', false),
                        _PlanFeature('Multi-Device Sync', false),
                      ],
                      isCurrentPlan: sub.isFree,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildPlanCard(
                      index: 1,
                      planName: 'Pro',
                      price: '₹149',
                      period: '/month',
                      icon: Icons.star_rounded,
                      gradStart: const Color(0xFF6366F1),
                      gradEnd: const Color(0xFF8B5CF6),
                      badge: 'POPULAR',
                      features: [
                        _PlanFeature('Unlimited Khatas', true),
                        _PlanFeature('All-Time Report History', true),
                        _PlanFeature('50 Saved Reports', true),
                        _PlanFeature('Download PDF & Excel', true),
                        _PlanFeature('Print Reports', true),
                        _PlanFeature('Ad-Free Experience', true),
                        _PlanFeature('Cloud Backup', false),
                        _PlanFeature('Multi-Device Sync', false),
                      ],
                      isCurrentPlan: sub.isPro && !sub.isPremium,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildPlanCard(
                      index: 2,
                      planName: 'Premium',
                      price: '₹299',
                      period: '/month',
                      icon: Icons.diamond_rounded,
                      gradStart: const Color(0xFF7C3AED),
                      gradEnd: const Color(0xFFDB2777),
                      badge: 'BEST VALUE',
                      features: [
                        _PlanFeature('Everything in Pro', true),
                        _PlanFeature('Unlimited Saved Reports', true),
                        _PlanFeature('Cloud Backup & Restore', true),
                        _PlanFeature('Multi-Device Sync', true),
                        _PlanFeature('Multi-Currency Support', true),
                        _PlanFeature('Custom PDF Branding', true),
                        _PlanFeature('Priority Support', true),
                      ],
                      isCurrentPlan: sub.isPremium,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    // Free trial banner
                    if (sub.isFree)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.celebration_rounded,
                                color: Color(0xFFF59E0B), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '🎉 Start with a 14-day free trial — no charge until trial ends!',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFFCD34D)
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom action area
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Upgrade button
                    if (_selectedPlanIndex > 0 || !sub.isFree)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Attempt RevenueCat native purchase flow
                            try {
                              final paywallResult = await RevenueCatUI.presentPaywall();
                              if (context.mounted) {
                                final purchased = paywallResult == PaywallResult.purchased ||
                                    paywallResult == PaywallResult.restored;
                                Navigator.of(context).pop(purchased);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Purchase will be available on a real device with Google Play.',
                                      style: GoogleFonts.inter(fontSize: 13),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedPlanIndex == 2
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _selectedPlanIndex == 0
                                ? 'Continue with Free'
                                : 'Start 14-Day Free Trial',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Cancel anytime · Restore purchases',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String planName,
    required String price,
    required String period,
    required IconData icon,
    required Color gradStart,
    required Color gradEnd,
    required List<_PlanFeature> features,
    required bool isCurrentPlan,
    required bool isDark,
    String? badge,
  }) {
    final isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? gradStart
                : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradStart.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [gradStart, gradEnd]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            planName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [gradStart, gradEnd]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badge,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          if (isCurrentPlan) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'CURRENT',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? gradStart
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      period,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                // Selection indicator
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? gradStart : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: 2,
                    ),
                    color: isSelected ? gradStart : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),

            // Features list (collapsible — show when selected)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isSelected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: features
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  f.included
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 16,
                                  color: f.included
                                      ? const Color(0xFF10B981)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : Colors.grey.shade300),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: f.included
                                          ? (isDark
                                              ? Colors.white.withValues(alpha: 0.8)
                                              : const Color(0xFF334155))
                                          : (isDark
                                              ? Colors.white.withValues(alpha: 0.3)
                                              : Colors.grey.shade400),
                                      decoration: f.included
                                          ? null
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanFeature {
  final String name;
  final bool included;
  _PlanFeature(this.name, this.included);
}
