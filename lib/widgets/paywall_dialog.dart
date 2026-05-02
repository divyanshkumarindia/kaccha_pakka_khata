import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../utils/debug_purchase_simulator.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _waveController;
  late Animation<double> _fadeAnimation;
  late int _selectedPlanIndex;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    
    // Set default plan based on current subscription
    final sub = Provider.of<SubscriptionService>(context, listen: false);
    if (sub.isFree) {
      _selectedPlanIndex = 1; // Default to Pro for Free users
    } else if (sub.isPro) {
      _selectedPlanIndex = 2; // Default to Premium for Pro users
    } else if (sub.isPremium) {
      _selectedPlanIndex = 2; // Stay on Premium for Premium users
    }

    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  /// Staggered plan selection: close current → wait → open new.
  /// This prevents the simultaneous expand/collapse visual glitch.
  void _selectPlan(int newIndex) {
    if (_isAnimating || newIndex == _selectedPlanIndex) return;
    _isAnimating = true;

    // Phase 1: Collapse current card
    setState(() => _selectedPlanIndex = -1);

    // Phase 2: After collapse starts, expand the new card
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _selectedPlanIndex = newIndex;
          _isAnimating = false;
        });
      }
    });
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A), // Deep Slate
                    const Color(0xFF1E293B), // Slate 800
                    const Color(0xFF111827), // Gray 900
                  ]
                : [
                    const Color(0xFFF8FAFC), // Slate 50
                    const Color(0xFFF1F5F9), // Slate 100
                    const Color(0xFFEEF2FF), // Indigo 50
                  ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: Stack(
            children: [
              // Decorative background shapes
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                        : const Color(0xFF6366F1).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -30,
                top: 150,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFD946EF).withValues(alpha: 0.05)
                        : const Color(0xFFD946EF).withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              
              Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

            // Compact Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Upgrade Your Khata',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.auto_awesome,
                          color: Color(0xFFF59E0B), size: 22),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the plan that works best for your business',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
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
                      context: context,
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
                    ),
                    const SizedBox(height: 12),
                    _buildPlanCard(
                      context: context,
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
                    ),
                    const SizedBox(height: 12),
                    _buildPlanCard(
                      context: context,
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
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Free trial banner (Locked at bottom)
                    if (sub.isFree)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.celebration_rounded,
                                color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '🎉 Start with a 14-day free trial — no charge until trial ends!',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
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

                    // Upgrade button
                    if (_selectedPlanIndex != 0 || !sub.isFree)
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          Color gradStart;
                          Color gradEnd;

                          if (_selectedPlanIndex == 2) {
                            gradStart = const Color.fromARGB(255, 57, 60, 211);
                            gradEnd = const Color(0xFFDB2777);
                          } else if (_selectedPlanIndex == 1) {
                            gradStart = const Color.fromARGB(255, 106, 78, 156);
                            gradEnd = const Color(0xFF8B5CF6);
                          } else {
                            // Free Plan
                            gradStart = isDark ? const Color(0xFF475569) : const Color(0xFF64748B);
                            gradEnd = isDark ? const Color(0xFF334155) : const Color(0xFF475569);
                          }

                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [gradStart, gradEnd, gradStart],
                                stops: const [0.0, 0.5, 1.0],
                                transform: _selectedPlanIndex == 0
                                    ? null
                                    : GradientRotation(
                                        _waveController.value * 2 * 3.14159,
                                      ),
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                // Test/Debug Flow:
                                await DebugPurchaseSimulator.simulatePurchase(
                                    context, _selectedPlanIndex);
                                if (context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _selectedPlanIndex == 0
                                    ? 'Continue with Free'
                                    : 'Start 14-Day Free Trial',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Cancel anytime',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
),
);
}

  Widget _buildPlanCard({
    required BuildContext context,
    required int index,
    required String planName,
    required String price,
    required String period,
    required IconData icon,
    required Color gradStart,
    required Color gradEnd,
    required List<_PlanFeature> features,
    required bool isCurrentPlan,
    String? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () => _selectPlan(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? gradStart
                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
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
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            planName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (badge != null)
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
                          if (isCurrentPlan)
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
                            ? (isDark ? Colors.white : gradStart)
                            : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
                      ),
                    ),
                    Text(
                      period,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : const Color(0xFF64748B),
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
                      color: isSelected ? gradStart : (isDark ? Colors.white24 : Colors.black12),
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

            // Features list (collapsible — smooth height animation)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1.0 : 0.0,
                child: isSelected
                    ? Padding(
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
                                              : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            f.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: f.included
                                                  ? (isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF334155))
                                                  : (isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF94A3B8)),
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
                      )
                    : const SizedBox.shrink(),
              ),
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
