import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../services/recent_service.dart';
import 'accounting_template_screen.dart';
import '../widgets/premium_components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserType? selectedUseCase;
  String? selectedCustomPageId; // For custom pages
  String?
      selectedPageId; // Combined selector: 'standard_personal', 'standard_business', or custom page ID
  String description = 'Description will appear here';

  String? _userName;

  // display titles for dropdown; can be overridden by user-saved values
  final Map<UserType, String> displayTitles = {};

  // Store custom pages: id -> title
  Map<String, String> customPages = {};

  final Map<UserType, String> descriptions = {
    UserType.personal:
        'Manage personal and family finances with income and expense tracking.',
    UserType.business:
        'Track sales, purchases, and business transactions efficiently.',
    UserType.institute: 'Manage fees, donations, and organizational finances.',
    UserType.other: 'Custom tracking for your specific needs.',
  };

  @override
  void initState() {
    super.initState();
    _loadPageTitles();
    _loadCustomPages();

    _loadRecents();
    _loadUserName();
    // Load default page type after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultPageType();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload page titles whenever this screen becomes visible
    // This ensures dropdown shows updated custom names
    _loadPageTitles();
    _loadCustomPages();
  }

  Future<void> _loadCustomPages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPages = prefs.getString('custom_pages');
    if (savedPages != null) {
      final decoded = jsonDecode(savedPages) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          customPages = decoded.map((k, v) => MapEntry(k, v.toString()));
        });
      }
    }
  }

  Future<void> _saveCustomPages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_pages', jsonEncode(customPages));
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    if (name == null) {
      // First time user, show dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNameInputDialog(context);
      });
    } else {
      if (mounted) {
        setState(() {
          _userName = name;
        });
      }
    }
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    if (mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

  void _showNameInputDialog(BuildContext context) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Force user to enter name
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasText = controller.text.trim().isNotEmpty;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Welcome!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Please enter your name to personalize your experience.',
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Your Name',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF334155) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: hasText
                      ? () {
                          _saveUserName(controller.text.trim());
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadDefaultPageType() async {
    final model = Provider.of<AccountingModel>(context, listen: false);
    final defaultPage = model.defaultPageType;

    // If None or empty, don't auto-select anything
    if (defaultPage == null || defaultPage.isEmpty || defaultPage == 'None') {
      return;
    }

    // Check if it's a custom page
    if (defaultPage.startsWith('custom_')) {
      setState(() {
        selectedPageId = defaultPage;
      });
      return;
    }

    // Handle standard page types
    UserType? selectedType;
    switch (defaultPage) {
      case 'Personal':
        selectedType = UserType.personal;
        break;
      case 'Business':
        selectedType = UserType.business;
        break;
      case 'Institute':
        selectedType = UserType.institute;
        break;
      case 'Other':
        selectedType = UserType.other;
        break;
    }

    if (selectedType != null) {
      setState(() {
        selectedUseCase = selectedType;
        description =
            descriptions[selectedType] ?? 'Description will appear here';
      });
    }
  }

  List<RecentPage> _recents = [];

  Future<void> _loadRecents() async {
    final list = await RecentService.listRecent();
    if (mounted) setState(() => _recents = list);
  }

  UserType _userTypeForTemplate(String key) {
    switch (key) {
      case 'family':
        return UserType.personal;
      case 'business':
        return UserType.business;
      case 'institute':
        return UserType.institute;
      default:
        return UserType.other;
    }
  }

  String _routeForTemplate(String key) {
    switch (key) {
      case 'family':
        return '/accounting/family';
      case 'business':
        return '/accounting/business';
      case 'institute':
        return '/accounting/institute';
      default:
        return '/accounting/other';
    }
  }

  Future<void> _loadPageTitles() async {
    // initialize with defaults
    for (var ut in UserType.values) {
      displayTitles[ut] = userTypeConfigs[ut]!.name;
    }
    // try load saved overrides
    for (var ut in UserType.values) {
      final saved = await AccountingModel.loadSavedPageTitle(ut);
      if (saved != null && saved.isNotEmpty) {
        displayTitles[ut] = saved;
      }
    }
    if (mounted) setState(() {});
  }

  void _showAddNewPageDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();

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
                SizedBox(width: 12),
                Text('New Accounting Page'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter a name for your new accounting page:',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (value) {
                    setDialogState(
                        () {}); // Rebuild dialog to update button state
                  },
                  decoration: InputDecoration(
                    hintText: 'e.g., Rental Property, Side Business',
                  ),
                ),
                if (!hasText)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Title is required',
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: hasText
                    ? () {
                        String pageName = controller.text.trim();
                        Navigator.pop(context);
                        _createAndNavigateToCustomPage(pageName);
                      }
                    : null, // Disable if no text
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  disabledForegroundColor: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _createAndNavigateToCustomPage(String pageName) async {
    // Generate unique ID for the custom page
    final pageId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

    // Save to custom pages
    setState(() {
      customPages[pageId] = pageName;
    });
    await _saveCustomPages();

    // Create a new model with UserType.other for custom pages
    final customModel = AccountingModel(userType: UserType.other);
    await customModel.loadFromPrefs();

    // Navigate to the new custom page with its own model
    final wasDeleted = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider<AccountingModel>.value(
          value: customModel,
          child: AccountingTemplateScreen(
            templateKey: 'other',
            customTitle: pageName,
            customPageId: pageId,
          ),
        ),
      ),
    );

    // Reload custom pages when returning (in case page was deleted)
    await _loadCustomPages();

    // If page was deleted, reset selection
    if (wasDeleted == true) {
      setState(() {
        selectedPageId = null;
      });
    }
  }

  Future<void> _handleNavigation(Map<String, dynamic> item) async {
    final String pageId = item['id'];
    final String type = item['type'];

    // Provide visual feedback
    setState(() {
      selectedPageId = pageId;
    });

    // Small delay to show selection
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    if (type == 'custom') {
      final customTitle = item['title'];

      // Create a new model with UserType.other for custom pages
      final customModel = AccountingModel(userType: UserType.other);
      await customModel.loadFromPrefs();

      // Navigate to custom page
      final wasDeleted = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider<AccountingModel>.value(
            value: customModel,
            child: AccountingTemplateScreen(
              templateKey: 'other',
              customTitle: customTitle,
              customPageId: pageId,
            ),
          ),
        ),
      );
      await _loadCustomPages();

      if (wasDeleted == true && mounted) {
        setState(() {
          selectedPageId = null;
        });
      }
    } else {
      // Standard page
      final ut = item['userType'] as UserType;

      // Navigate to standard page
      final model = AccountingModel(userType: ut);
      await model.loadFromPrefs();

      String route = '/accounting';
      switch (ut) {
        case UserType.personal:
          route = '/accounting/family';
          break;
        case UserType.business:
          route = '/accounting/business';
          break;
        case UserType.institute:
          route = '/accounting/institute';
          break;
        case UserType.other:
          route = '/accounting/other';
          break;
      }

      if (!mounted) return;
      await Navigator.pushNamed(context, route, arguments: model);
      await _loadPageTitles();
    }

    await _loadRecents();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'My Kaccha-Pakka Khata',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Text(
                  _userName != null ? 'Welcome, $_userName!' : 'Welcome!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium Financial Management',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontSize: 16,
                      ),
                ),

                const SizedBox(height: 32),

                // Features Section (Moved to Top)
                // Feature Carousel (Hero Cards)
                SizedBox(
                  height: 140, // Height for premium cards
                  child: PageView(
                    controller: PageController(viewportFraction: 0.92),
                    padEnds: false,
                    children: [
                      _buildFeatureCard(
                        context,
                        'Track Receipts',
                        'Log every earning instantly.',
                        Icons.receipt_long_rounded,
                        const Color(0xFF10B981), // Emerald
                        isDark,
                      ),
                      _buildFeatureCard(
                        context,
                        'Manage Expenses',
                        'Keep spending in check.',
                        Icons.payments_rounded,
                        const Color(0xFFEF4444), // Red
                        isDark,
                      ),
                      _buildFeatureCard(
                        context,
                        'Smart Reports',
                        'Visualize financial health.',
                        Icons.analytics_rounded,
                        const Color(0xFF8B5CF6), // Violet
                        isDark,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Main Selection Card
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Your Use Case',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Grid Layout for Use Cases
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Prepare list of items
                          final List<Map<String, dynamic>> items = [];

                          // Add standard types
                          for (var ut in UserType.values) {
                            IconData icon;
                            Color color;
                            switch (ut) {
                              case UserType.personal:
                                icon = Icons.family_restroom_rounded;
                                color = const Color(0xFFEF4444); // Red
                                break;
                              case UserType.business:
                                icon = Icons.store_rounded;
                                color = const Color(0xFF10B981); // Emerald
                                break;
                              case UserType.institute:
                                icon = Icons.school_rounded;
                                color = const Color(0xFF2563EB); // Blue
                                break;
                              case UserType.other:
                                icon = Icons.category_rounded;
                                color = const Color(0xFFF59E0B); // Amber
                                break;
                            }
                            items.add({
                              'id': 'standard_${ut.toString().split('.').last}',
                              'title': displayTitles[ut] ??
                                  userTypeConfigs[ut]!.name,
                              'icon': icon,
                              'type': 'standard',
                              'userType': ut,
                              'color': color,
                            });
                          }

                          // Palette for custom pages to ensure variety
                          final palette = [
                            const Color(0xFFEF4444), // Red
                            const Color(0xFF2563EB), // Blue
                            const Color(0xFFCA8A04), // Yellow/Gold
                            const Color(0xFF9333EA), // Purple
                            const Color(0xFF10B981), // Emerald
                            const Color(0xFFEA580C), // Orange
                            const Color(0xFF0891B2), // Cyan
                            const Color(0xFFDB2777), // Pink
                            const Color(0xFF65A30D), // Lime
                            const Color(0xFF4F46E5), // Indigo
                            const Color(0xFFDC2626), // Deep Orange
                            const Color(0xFF0D9488), // Teal
                            const Color(0xFF7C3AED), // Violet
                            const Color(0xFFD97706), // Amber
                            const Color(0xFF0284C7), // Light Blue
                            const Color(0xFFC026D3), // Fuchsia
                            const Color(0xFF16A34A), // Green
                            const Color(0xFF795548), // Brown
                            const Color(0xFF607D8B), // Blue Grey
                          ];

                          // Add custom pages
                          int customIndex = 0;
                          customPages.forEach((key, value) {
                            // Sequential assignment to avoid repeats until palette is exhausted
                            final colorIndex = customIndex % palette.length;
                            items.add({
                              'id': key,
                              'title': value,
                              'icon': Icons.star_rounded,
                              'type': 'custom',
                              'color': palette[colorIndex],
                            });
                            customIndex++;
                          });

                          // Add "Add New" card
                          items.add({
                            'id': 'add_new',
                            'title': 'Add New Page',
                            'icon': Icons.add_rounded,
                            'type': 'add_new',
                            'color': const Color(0xFF94A3B8), // Neutral Gray
                          });

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.1, // Adjust for card height
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isSelected = selectedPageId == item['id'];
                              final Color itemColor =
                                  item['color'] as Color; // Use item color

                              return InkWell(
                                onTap: () {
                                  if (item['type'] == 'add_new') {
                                    _showAddNewPageDialog(context);
                                  } else {
                                    _handleNavigation(item);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: itemColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: itemColor.withValues(alpha: 0.6),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: itemColor.withValues(
                                              alpha: 0.1), // Fixed tint
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          item['icon'] as IconData,
                                          color: itemColor, // Vibrant icon
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text(
                                          item['title'] as String,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // Recent Pages Section
                if (_recents.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  PremiumCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history_rounded,
                                size: 20,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Pages',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(
                          _recents.length > 3 ? 3 : _recents.length,
                          (idx) {
                            final recent = _recents[idx];
                            final userType =
                                _userTypeForTemplate(recent.templateKey);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    final model =
                                        AccountingModel(userType: userType);
                                    await model.loadFromPrefs();
                                    final route =
                                        _routeForTemplate(recent.templateKey);
                                    await Navigator.pushNamed(context, route,
                                        arguments: model);
                                    _loadPageTitles();
                                    _loadRecents();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                recent.displayTitle,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              Text(
                                                userTypeConfigs[userType]!.name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 16,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.05 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
