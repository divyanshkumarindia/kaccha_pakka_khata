import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _cardKeys = List.generate(5, (_) => GlobalKey());

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

  final List<_DurationOption> _premiumOptions = const [
    _DurationOption(
      id: 'premium_monthly:premium-monthly-bp',
      label: 'Monthly Plan',
      price: '₹199',
      monthlyEquivalent: '₹199/mo',
      isTrial: true,
      badge: '30 Days Free',
    ),
    _DurationOption(
      id: 'premium_yearly:premium-yearly-bp',
      label: 'Yearly Plan',
      price: '₹2,199',
      monthlyEquivalent: '₹183/mo',
      originalPrice: '₹2,388',
      isTrial: true,
      badge: '30 Days Free • Save 10%',
    ),
    _DurationOption(
      id: 'premium_2_year',
      label: '2 Years Access',
      price: '₹3,199',
      monthlyEquivalent: '₹133/mo',
      originalPrice: '₹3,999',
      isTrial: false,
      badge: 'Save 20%',
    ),
    _DurationOption(
      id: 'premium_3_year',
      label: '3 Years Access',
      price: '₹4,499',
      monthlyEquivalent: '₹125/mo',
      originalPrice: '₹5,999',
      isTrial: false,
      badge: 'Save 25%',
    ),
    _DurationOption(
      id: 'premium_5_year',
      label: '5 Years Access',
      price: '₹5,599',
      monthlyEquivalent: '₹93/mo',
      originalPrice: '₹7,999',
      isTrial: false,
      badge: 'Save 30% • BEST VALUE',
    ),
  ];

  bool _ownsOption(_DurationOption opt) {
    final sub = Provider.of<SubscriptionService>(context, listen: false);
    if (sub.isFree) return false;

    // 1. Check if the tier (pro/premium) matches the option type
    final isPremiumOption = opt.id.startsWith('premium');
    if (isPremiumOption != sub.isPremium) return false;

    // 2. Check by active product ID (RevenueCat)
    if (sub.activeProductId != null) {
      final activeId = sub.activeProductId!;
      if (opt.id == activeId || activeId.contains(opt.id.split(':').first)) {
        return true;
      }
    }

    // 3. Check by active database override duration days
    if (sub.activeDurationDays != null) {
      final days = sub.activeDurationDays!;
      String expectedOptionSuffix = '';
      if (days <= 30) {
        expectedOptionSuffix = 'monthly';
      } else if (days <= 90) {
        expectedOptionSuffix = 'monthly';
      } else if (days <= 365) {
        expectedOptionSuffix = 'yearly';
      } else if (days <= 730) {
        expectedOptionSuffix = '2_year';
      } else if (days <= 1095) {
        expectedOptionSuffix = '3_year';
      } else {
        expectedOptionSuffix = '5_year';
      }
      if (opt.id.contains(expectedOptionSuffix)) {
        return true;
      }
    }
    return false;
  }

  void _scrollToSelectedIfNeeded({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        final key = _cardKeys[_selectedDurationIndex];
        final context = key.currentContext;
        if (context != null) {
          if (animate) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
            );
          } else {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
            );
          }
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // Default selection logic based on current subscription state
    final sub = Provider.of<SubscriptionService>(context, listen: false);
    if (sub.isPremium) {
      _isPremiumSelected = true;
    } else if (sub.isPro) {
      _isPremiumSelected = false;
    } else {
      _isPremiumSelected = false; // Guide Free users to Pro first
    }

    // Auto-select index based on owned plan duration/id
    final optionsList = _isPremiumSelected ? _premiumOptions : _proOptions;
    for (int i = 0; i < optionsList.length; i++) {
      if (_ownsOption(optionsList[i])) {
        _selectedDurationIndex = i;
        break;
      }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedIfNeeded(animate: false);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
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

  void _showPromoCodeDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();
    final primaryColor = _isPremiumSelected ? const Color(0xFFDB2777) : const Color(0xFF6366F1);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.local_offer_rounded, color: primaryColor),
            const SizedBox(width: 12),
            Text(
              'Redeem Promo Code',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Google Play promotional code below to redeem your offer.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'e.g. PLAYSTOREPROMO123',
                hintStyle: GoogleFonts.inter(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF374151) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://play.google.com/redeem');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.store_rounded, size: 16),
                label: Text(
                  'Open Play Store Redeem Screen',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              Navigator.pop(context);
              
              if (code.isNotEmpty) {
                final subService = Provider.of<SubscriptionService>(context, listen: false);
                final res = await subService.redeemPromoCode(code);
                
                if (res['success'] == true) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🎉 Promo code redeemed! Plan upgraded to ${res['plan'] == SubscriptionPlan.premium ? 'Premium' : 'Pro'}.', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.of(context).pop(true); // Close the paywall dialog
                  }
                } else {
                  final msg = res['message'] as String;
                  if (msg.toLowerCase().contains('limit') || 
                      msg.toLowerCase().contains('redeemed') || 
                      msg.toLowerCase().contains('exist') || 
                      msg.toLowerCase().contains('invalid')) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg, style: GoogleFonts.inter()),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    // Fallback to Google Play Store deep-link redemption
                    final url = Uri.parse('https://play.google.com/redeem?code=$code');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not launch Play Store.', style: GoogleFonts.inter()),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  }
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid code.', style: GoogleFonts.inter()),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text('Redeem', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                                  final optionsList = _proOptions;
                                  int foundIndex = -1;
                                  for (int i = 0; i < optionsList.length; i++) {
                                    if (_ownsOption(optionsList[i])) {
                                      foundIndex = i;
                                      break;
                                    }
                                  }
                                  if (foundIndex != -1) {
                                    _selectedDurationIndex = foundIndex;
                                  } else {
                                    _selectedDurationIndex = 1;
                                  }
                                });
                                _scrollToSelectedIfNeeded();
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
                                  final optionsList = _premiumOptions;
                                  int foundIndex = -1;
                                  for (int i = 0; i < optionsList.length; i++) {
                                    if (_ownsOption(optionsList[i])) {
                                      foundIndex = i;
                                      break;
                                    }
                                  }
                                  if (foundIndex != -1) {
                                    _selectedDurationIndex = foundIndex;
                                  } else {
                                    _selectedDurationIndex = 1;
                                  }
                                });
                                _scrollToSelectedIfNeeded();
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
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Monthly option card (Index 0)
                          _buildDurationOptionCard(
                            context,
                            0,
                            options[0],
                            primaryColor,
                            secondaryColor,
                            isDark,
                          ),
                          const SizedBox(height: 14),

                          // Yearly option card (Index 1)
                          _buildDurationOptionCard(
                            context,
                            1,
                            options[1],
                            primaryColor,
                            secondaryColor,
                            isDark,
                          ),

                          // Nested multi-year section (Indices 2, 3, 4)
                          _buildNestedYearlySection(
                            context,
                            options,
                            primaryColor,
                            secondaryColor,
                            isDark,
                          ),

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
                          // Active Plan confirmation or checkout CTA button
                          if (_ownsOption(selectedOption))
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF10B981),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Active Subscription',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'You currently possess this plan.',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
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
                          ],

                          const SizedBox(height: 12),

                          // Quick Actions Row (Promo, Restore)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: _showPromoCodeDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    'Redeem Promo Code',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
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

  Widget _buildDurationOptionCard(
    BuildContext context,
    int index,
    _DurationOption opt,
    Color primaryColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final isSelected = _selectedDurationIndex == index;

    return InkWell(
      key: _cardKeys[index],
      onTap: () {
        setState(() {
          _selectedDurationIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.white),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          primaryColor.withValues(alpha: 0.15),
                          secondaryColor.withValues(alpha: 0.04),
                        ]
                      : [
                          primaryColor.withValues(alpha: 0.08),
                          secondaryColor.withValues(alpha: 0.015),
                        ],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Beautiful interactive radio selector
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryColor : (isDark ? Colors.white30 : Colors.black26),
                  width: isSelected ? 8 : 2,
                ),
                color: isSelected ? Colors.white : Colors.transparent,
              ),
            ),
            const SizedBox(width: 14),

            // Duration name and monthly equivalent
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
                        opt.label,
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (_ownsOption(opt))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'CURRENT',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (opt.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, secondaryColor],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            opt.badge!,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF475569),
                      ),
                      children: [
                        const TextSpan(text: 'Equivalent to '),
                        TextSpan(
                          text: opt.monthlyEquivalent,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isSelected ? primaryColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Pricing segment
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (opt.originalPrice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      opt.originalPrice!,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                Text(
                  opt.price,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  opt.isTrial ? 'then auto-renews' : 'one-time purchase',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.8)
                        : (isDark ? Colors.white30 : Colors.black38),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNestedYearlySection(
    BuildContext context,
    List<_DurationOption> options,
    Color primaryColor,
    Color secondaryColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: primaryColor.withValues(alpha: 0.35),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'EXCLUSIVE MULTI-YEAR ACCESS PLANS:',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.black54,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(3, (index) {
            final actualIndex = index + 2; // Index 2, 3, 4
            final opt = options[actualIndex];
            final isSelected = _selectedDurationIndex == actualIndex;

            return Container(
              key: _cardKeys[actualIndex],
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDurationIndex = actualIndex;
                  });
                },
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? null
                        : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : Colors.white),
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    primaryColor.withValues(alpha: 0.12),
                                    secondaryColor.withValues(alpha: 0.03),
                                  ]
                                : [
                                    primaryColor.withValues(alpha: 0.06),
                                    secondaryColor.withValues(alpha: 0.01),
                                  ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                      width: isSelected ? 2.2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      // Radio selector
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? primaryColor : (isDark ? Colors.white30 : Colors.black26),
                            width: isSelected ? 7 : 2,
                          ),
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Option description
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
                                  opt.label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (_ownsOption(opt))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle, size: 10, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          'CURRENT',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (opt.badge != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF475569),
                                ),
                                children: [
                                  const TextSpan(text: 'Equivalent to '),
                                  TextSpan(
                                    text: opt.monthlyEquivalent,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? primaryColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Pricing
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (opt.originalPrice != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                opt.originalPrice!,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFEF4444),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          Text(
                            opt.price,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'one-time purchase',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.8)
                                  : (isDark ? Colors.white30 : Colors.black38),
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
        ],
      ),
    );
  }
}

