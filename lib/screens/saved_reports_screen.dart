import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import 'category_reports_screen.dart';

class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() => _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  // Store custom pages: id -> title
  Map<String, String> _customPages = {};

  // Palette for custom pages
  final List<Color> _customPalette = const [
    Color(0xFFEF4444), // Red
    Color(0xFF0891B2), // Cyan
    Color(0xFFDB2777), // Pink
    Color(0xFFEA580C), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomPages();
  }

  Future<void> _loadCustomPages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPages = prefs.getString('custom_pages');
    if (savedPages != null) {
      final decoded = jsonDecode(savedPages) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _customPages = decoded.map((k, v) => MapEntry(k, v.toString()));
        });
      }
    }
  }

  Future<void> _saveCustomPages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_pages', jsonEncode(_customPages));
  }

  void _showAddNewPageDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();
    final model = Provider.of<AccountingModel>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasText = controller.text.trim().isNotEmpty;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.add_circle_outline,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(model.t('dialog_new_page_title')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.t('dialog_new_page_msg'),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: model.t('hint_new_page'),
                  ),
                ),
                if (!hasText)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      model.t('err_title_required'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(model.t('btn_cancel')),
              ),
              ElevatedButton(
                onPressed: hasText
                    ? () {
                        final pageName = controller.text.trim();
                        Navigator.pop(context);
                        _createCustomPage(pageName);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  disabledForegroundColor: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                child: Text(model.t('btn_create')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createCustomPage(String pageName) async {
    final pageId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _customPages[pageId] = pageName;
    });
    await _saveCustomPages();
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<AccountingModel>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Prepare standard items
    final List<Widget> items = [];

    // 1. Personal
    items.add(_buildCategoryCard(
      context,
      title: model.pageHeaderTitles['family'] ?? model.t('card_personal'),
      icon: Icons.person_outline_rounded,
      color: const Color(0xFF3B82F6), // Stronger Blue
      isActive: model.userType == UserType.personal,
      onTap: () => _navigateToReports(
        context,
        model.pageHeaderTitles['family'] ?? model.t('card_personal'),
        'Personal',
        const Color(0xFF3B82F6),
      ),
      isDark: isDark,
    ));

    // 2. Business
    items.add(_buildCategoryCard(
      context,
      title: model.pageHeaderTitles['business'] ?? model.t('card_business'),
      icon: Icons.storefront_rounded,
      color: const Color(0xFF10B981), // Emerald Green
      isActive: model.userType == UserType.business,
      onTap: () => _navigateToReports(
        context,
        model.pageHeaderTitles['business'] ?? model.t('card_business'),
        'Business',
        const Color(0xFF10B981),
      ),
      isDark: isDark,
    ));

    // 3. Institute
    items.add(_buildCategoryCard(
      context,
      title: model.pageHeaderTitles['institute'] ?? model.t('card_institute'),
      icon: Icons.school_rounded,
      color: const Color(0xFF7C3AED), // Violet
      isActive: model.userType == UserType.institute,
      onTap: () => _navigateToReports(
        context,
        model.pageHeaderTitles['institute'] ?? model.t('card_institute'),
        'Institute',
        const Color(0xFF7C3AED),
      ),
      isDark: isDark,
    ));

    // 4. Other
    items.add(_buildCategoryCard(
      context,
      title: model.pageHeaderTitles['other'] ?? model.t('card_other'),
      icon: Icons.widgets_rounded,
      color: const Color(0xFFD97706), // Amber
      isActive: model.userType == UserType.other,
      onTap: () => _navigateToReports(
        context,
        model.pageHeaderTitles['other'] ?? model.t('card_other'),
        'Other',
        const Color(0xFFD97706),
      ),
      isDark: isDark,
    ));

    // 5. Custom Pages
    int customIndex = 0;
    _customPages.forEach((id, defaultTitle) {
      final color = _customPalette[customIndex % _customPalette.length];
      final displayTitle = model.pageHeaderTitles[id] ?? defaultTitle;

      items.add(_buildCategoryCard(
        context,
        title: displayTitle,
        icon: Icons.star_outline_rounded,
        color: color,
        isActive: false,
        onTap: () => _navigateToReports(
          context,
          displayTitle,
          id,
          color,
        ),
        isDark: isDark,
      ));
      customIndex++;
    });

    // 6. Add New Button
    items.add(_buildAddNewCard(context, isDark));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 24, bottom: 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.t('title_saved_reports'), // "Saved Reports"
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'View your saved balance sheets and history for each specific account type.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Decorative Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.snippet_folder_rounded,
                        size: 32,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.blue.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Grid Content
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.05, // Square-ish but slightly tall
                children: items,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToReports(
      BuildContext context, String title, String useCase, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryReportsScreen(
          categoryName: title,
          useCaseType: useCase,
          categoryColor: color,
        ),
      ),
    );
  }

  Widget _buildAddNewCard(BuildContext context, bool isDark) {
    return _PremiumCategoryCard(
      title: 'Add New',
      icon: Icons.add_rounded,
      color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
      isDark: isDark,
      onTap: () => _showAddNewPageDialog(context),
      isAddNew: true,
      isActive: false,
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return _PremiumCategoryCard(
      title: title,
      icon: icon,
      color: color,
      isDark: isDark,
      isActive: isActive,
      onTap: onTap,
    );
  }
}

class _PremiumCategoryCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool isActive;
  final bool isAddNew;
  final VoidCallback onTap;

  const _PremiumCategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.isActive,
    this.isAddNew = false,
    required this.onTap,
  });

  @override
  State<_PremiumCategoryCard> createState() => _PremiumCategoryCardState();
}

class _PremiumCategoryCardState extends State<_PremiumCategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    // Gradient Setup
    Gradient? gradient;
    Color iconColor;
    Color textColor;
    BoxShadow? shadow;

    if (widget.isAddNew) {
      gradient = null; // Flat color for Add New
      iconColor = isDark ? Colors.white54 : Colors.grey.shade500;
      textColor = isDark ? Colors.white54 : Colors.grey.shade600;
    } else {
      // 3D Gradient for categories
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.color.withValues(alpha: 0.9),
          widget.color,
        ],
      );
      iconColor = Colors.white;
      textColor = Colors.white;

      shadow = BoxShadow(
        color: widget.color.withValues(alpha: 0.4),
        blurRadius: 12,
        offset: const Offset(0, 8),
        spreadRadius: -4,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isAddNew ? widget.color : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (shadow != null) shadow,
              if (widget.isAddNew && isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
            border: widget.isAddNew
                ? Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                    width: 2,
                    style: BorderStyle.solid,
                  )
                : null,
          ),
          child: Stack(
            children: [
              // Decorative Circle in background (Glassy)
              if (!widget.isAddNew)
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon Container
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.isAddNew
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 28,
                        color: iconColor,
                      ),
                    ),

                    const Spacer(),

                    // Title
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Active Dot
              if (widget.isActive)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
