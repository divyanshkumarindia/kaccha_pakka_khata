import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

/// An industrial-grade, gorgeous dynamic paywall dialog that presents the
/// full Kaccha Pakka Khata subscription and multi-year access suite.
/// Allows toggling between Pro & Premium and selecting from 5 distinct durations.
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

class _DurationOption {
  final String id;
  final String label;
  final String price;
  final String monthlyEquivalent;
  final String? originalPrice;
  final String? badge;
  final bool isTrial;

  const _DurationOption({
    required this.id,
    required this.label,
    required this.price,
    required this.monthlyEquivalent,
    this.originalPrice,
    this.badge,
    required this.isTrial,
  });
}

class _PaywallDialogState extends State<PaywallDialog>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  
  bool _isPremiumSelected = true;
  int _selectedDurationIndex = 1; // Default to Yearly Plan
  bool _isPurchasing = false;

  // Duration choices for Pro Plan
  final List<_DurationOption> _proOptions = const [
    _DurationOption(
      id: 'pro_monthly:pro-monthly-bp',
      label: 'Monthly Plan',
      price: '₹149',
      monthlyEquivalent: '₹149/mo',
      isTrial: true,
      badge: '30 Days Free',
    ),
    _DurationOption(
      id: 'pro_yearly:pro-yearly-bp',
      label: 'Yearly Plan',
      price: '₹1,599',
      monthlyEquivalent: '₹133/mo',
      originalPrice: '₹1,788',
      isTrial: true,
      badge: '30 Days Free • Save 10%',
    ),
    _DurationOption(
      id: 'pro_2_year',
      label: '2 Years Access',
      price: '₹2,399',
      monthlyEquivalent: '₹99/mo',
      originalPrice: '₹2,999',
      isTrial: false,
      badge: 'Save 20%',
    ),
    _DurationOption(
      id: 'pro_3_year',
      label: '3 Years Access',
      price: '₹2,999',
      monthlyEquivalent: '₹83/mo',
      originalPrice: '₹3,999',
      isTrial: false,
      badge: 'Save 25%',
    ),
    _DurationOption(
      id: 'pro_5_year',
      label: '5 Years Access',
      price: '₹3,499',
      monthlyEquivalent: '₹58/mo',
      originalPrice: '₹4,999',
      isTrial: false,
      badge: 'Save 30% • BEST VALUE',
    ),
  ];

  // Duration choices for Premium Plan
  final List<_DurationOption> _premiumOptions = const [
    _DurationOption(
      id: 'premium_monthly:premium-monthly-bp',
      label: 'Monthly Plan',
      price: '₹299',
      monthlyEquivalent: '₹299/mo',
      isTrial: true,
      badge: '30 Days Free',
    ),
    _DurationOption(
      id: 'premium_yearly:premium-yearly-bp',
      label: 'Yearly Plan',
      price: '₹3,199',
      monthlyEquivalent: '₹266/mo',
      originalPrice: '₹3,588',
      isTrial: true,
      badge: '30 Days Free • Save 10%',
    ),
    _DurationOption(
      id: 'premium_2_year',
      label: '2 Years Access',
      price: '₹4,799',
      monthlyEquivalent: '₹199/mo',
      originalPrice: '₹5,999',
      isTrial: false,
      badge: 'Save 20%',
    ),
    _DurationOption(
      id: 'premium_3_year',
      label: '3 Years Access',
      price: '₹5,999',
      monthlyEquivalent: '₹166/mo',
      originalPrice: '₹7,999',
      isTrial: false,
      badge: 'Save 25%',
    ),
    _DurationOption(
      id: 'premium_5_year',
      label: '5 Years Access',
      price: '₹6,999',
      monthlyEquivalent: '116/mo',
      originalPrice: '₹9,999',
      isTrial: false,
      badge: 'Save 30% • BEST VALUE',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Default selection logic based on current subscription state
    final sub = Provider.of<SubscriptionService>(context, listen: false);
    if (sub.isPro) {
      _isPremiumSelected = true; // Guide Pro users to upgrade to Premium
    } else {
      _isPremiumSelected = false; // Guide Free users to Pro first
    }

    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    final subService = Provider.of<SubscriptionService>(context, listen: false);
    final selectedOption = _isPremiumSelected
        ? _premiumOptions[_selectedDurationIndex]
        : _proOptions[_selectedDurationIndex];

    try {
      final newPlan = await subService.purchaseProduct(selectedOption.id);
      if (mounted && newPlan != SubscriptionPlan.free) {
        // Show celebratory feedback and close
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Welcome to ${newPlan == SubscriptionPlan.premium ? 'Premium' : 'Pro'}! Enjoy your access!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed. Please try again.', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    final subService = Provider.of<SubscriptionService>(context, listen: false);
    try {
      final plan = await subService.restorePurchases();
      if (mounted) {
        if (plan != SubscriptionPlan.free) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully restored subscription: ${plan == SubscriptionPlan.premium ? 'Premium' : 'Pro'}!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No active purchases found to restore.'),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Restore failed. Please try again.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final options = _isPremiumSelected ? _premiumOptions : _proOptions;
    final selectedOption = options[_selectedDurationIndex];

    final Color primaryColor = _isPremiumSelected ? const Color(0xFFDB2777) : const Color(0xFF6366F1);
    final Color secondaryColor = _isPremiumSelected ? const Color(0xFF7C3AED) : const Color(0xFF8B5CF6);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.94),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0B0F19), // Extra Deep Slate
                    const Color(0xFF111827), // Slate 900
                    const Color(0xFF0F172A),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFEEF2FF),
                    const Color(0xFFF5F3FF),
                  ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: Stack(
            children: [
              // Beautiful ambient decorative glow spheres
              Positioned(
                right: -60,
                top: -60,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -80,
                top: screenHeight * 0.25,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: secondaryColor.withValues(alpha: isDark ? 0.06 : 0.03),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clean minimalist drag indicator
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 14, bottom: 12),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header with modern styled app name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'KACCHA PAKKA KHATA',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.0,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Unleash Unlimited Business Growth',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // --- Spectacular Tab Selector for Pro vs Premium ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPremiumSelected = false;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: !_isPremiumSelected
                                      ? const LinearGradient(
                                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                        )
                                      : null,
                                  color: _isPremiumSelected ? Colors.transparent : null,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: !_isPremiumSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 18,
                                        color: !_isPremiumSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Pro Tier',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: !_isPremiumSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPremiumSelected = true;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: _isPremiumSelected
                                      ? const LinearGradient(
                                          colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                                        )
                                      : null,
                                  color: !_isPremiumSelected ? Colors.transparent : null,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _isPremiumSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFDB2777).withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.diamond_rounded,
                                        size: 18,
                                        color: _isPremiumSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Premium',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _isPremiumSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- Duration Cards (Scrollable Viewport) ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Duration cards mapped dynamically
                          ...List.generate(options.length, (index) {
                            final opt = options[index];
                            final isSelected = _selectedDurationIndex == index;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDurationIndex = index;
                                  });
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? primaryColor.withValues(alpha: 0.08) : Colors.white)
                                        : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.015)),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: primaryColor.withValues(alpha: 0.12),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      // Beautiful radio selector
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? primaryColor : (isDark ? Colors.white30 : Colors.black38),
                                            width: isSelected ? 6 : 2,
                                          ),
                                          color: isSelected ? Colors.transparent : Colors.transparent,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Duration name and monthly equivalent
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  opt.label,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                if (opt.badge != null) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [primaryColor, secondaryColor],
                                                      ),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      opt.badge!,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Equivalent to just ${opt.monthlyEquivalent}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Pricing segment
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (opt.originalPrice != null) ...[
                                                Text(
                                                  opt.originalPrice!,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.red.withValues(alpha: 0.8),
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Text(
                                                opt.price,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            opt.isTrial ? 'then auto-renews' : 'one-time purchase',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w400,
                                              color: isDark ? Colors.white30 : Colors.black38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 18),

                          // --- Selected Tier Benefits (Dynamic) ---
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isPremiumSelected ? '🚀 Premium Features Included:' : '✨ Pro Features Included:',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_isPremiumSelected) ...[
                                  _buildFeatureBullet(Icons.check_circle_outline, 'Everything in Pro tier', isDark),
                                  _buildFeatureBullet(Icons.cloud_done_outlined, 'Secure Cloud Backup & Restore', isDark),
                                  _buildFeatureBullet(Icons.sync_rounded, 'Real-time Multi-Device Sync', isDark),
                                  _buildFeatureBullet(Icons.payments_outlined, 'Multi-Currency operations', isDark),
                                  _buildFeatureBullet(Icons.image_outlined, 'Custom branding on PDF exports', isDark),
                                ] else ...[
                                  _buildFeatureBullet(Icons.check_circle_outline, 'Unlimited Khatas (vs 2 on Free)', isDark),
                                  _buildFeatureBullet(Icons.history_rounded, 'All-time access to ledger reports', isDark),
                                  _buildFeatureBullet(Icons.picture_as_pdf_outlined, 'Professional PDF & Excel reports', isDark),
                                  _buildFeatureBullet(Icons.block_rounded, '100% Ad-Free interface', isDark),
                                  _buildFeatureBullet(Icons.print_rounded, 'Direct-to-printer ledger printing', isDark),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // --- Bottom CTA Locking Section ---
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 30-Day Free Trial Notice Banner
                          if (selectedOption.isTrial)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.celebration, color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '🎉 Includes a 30-Day Free Trial — no charge until trial ends!',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_open_rounded, color: Color(0xFFF59E0B), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '🔑 One-time activation for long-term multi-year access!',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Pulsating Checkout CTA Button
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final double scale = 1.0 + (_pulseController.value * 0.02);
                              return Transform.scale(
                                scale: _isPurchasing ? 1.0 : scale,
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: LinearGradient(
                                      colors: [primaryColor, secondaryColor],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isPurchasing ? null : _handlePurchase,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: _isPurchasing
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            selectedOption.isTrial
                                                ? 'Start 30-Day Free Trial'
                                                : 'Activate ${selectedOption.label}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // Quick Actions Row (Restore, Legal)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Play Store Purchase',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                              GestureDetector(
                                onTap: _handleRestore,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    'Restore Purchases',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildFeatureBullet(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: _isPremiumSelected ? const Color(0xFFDB2777) : const Color(0xFF6366F1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
