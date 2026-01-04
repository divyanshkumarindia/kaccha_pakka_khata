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
        title: Text(
          'My Kaccha-Pakka Khata',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Group
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366F1).withValues(alpha: 0.1),
                            const Color(0xFF818CF8).withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome Back!',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Premium Financial Management',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontSize: 16,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Main Selection Card
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Your Use Case',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          // New "Add Page" button in header
                          IconButton(
                            onPressed: () => _showAddNewPageDialog(context),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            color: Theme.of(context).primaryColor,
                            tooltip: 'New Accounting Page',
                          ),
                        ],
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
                                color = const Color(0xFF6366F1); // Indigo
                                break;
                              case UserType.business:
                                icon = Icons.store_rounded;
                                color = const Color(0xFF10B981); // Emerald
                                break;
                              case UserType.institute:
                                icon = Icons.school_rounded;
                                color = const Color(0xFF8B5CF6); // Violet
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

                          // Add custom pages
                          customPages.forEach((key, value) {
                            items.add({
                              'id': key,
                              'title': value,
                              'icon': Icons.star_rounded,
                              'type': 'custom',
                              'color': const Color(0xFF06B6D4), // Cyan
                            });
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
                                onTap: () => _handleNavigation(item),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? itemColor.withValues(alpha: 0.15)
                                        : (isDark
                                            ? itemColor.withValues(alpha: 0.05)
                                            : itemColor.withValues(
                                                alpha: 0.03)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? itemColor
                                          : itemColor.withValues(alpha: 0.2),
                                      width: isSelected ? 2 : 1,
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
                                    await _loadPageTitles();
                                    await _loadRecents();
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

                // Features Section
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'Track\nReceipts',
                        isDark: isDark,
                        context: context,
                      ),
                      _buildFeatureItem(
                        icon: Icons.payments_rounded,
                        label: 'Track\nPayments',
                        isDark: isDark,
                        context: context,
                      ),
                      _buildFeatureItem(
                        icon: Icons.analytics_rounded,
                        label: 'Smart\nReports',
                        isDark: isDark,
                        context: context,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required bool isDark,
    required BuildContext context,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF64748B).withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
