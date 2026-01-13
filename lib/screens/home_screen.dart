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

    // Prompt for name if needed and sync cloud data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = Provider.of<AccountingModel>(context, listen: false);
      model.loadFromCloud(); // Fetch data from Supabase on login/startup
      _checkAndShowNameDialog();
      _loadDefaultPageType();
    });
  }

  void _checkAndShowNameDialog() {
    final model = Provider.of<AccountingModel>(context, listen: false);
    // If name is null and user hasn't skipped, show dialog
    if (model.userName == null && !model.hasSkippedNameSetup) {
      _showNameInputDialog(context);
    }
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

  void _showNameInputDialog(BuildContext context) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();
    final model = Provider.of<AccountingModel>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false, // Force user to enter name or skip
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasText = controller.text.trim().isNotEmpty;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
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
                          isDark ? const Color(0xFF374151) : Colors.grey[100],
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
                TextButton(
                  onPressed: () {
                    model.setSkippedNameSetup(true);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: hasText
                      ? () {
                          final name = controller.text.trim();
                          model.setUserName(name);
                          model.setSkippedNameSetup(
                              false); // Ensure skip is false if they save
                          Navigator.pop(context);

                          // Show toast message after dialog closes
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'You can change your username later in Settings.'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
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
        toolbarHeight: 70, // Increase height for two-line text
        title: Row(
          children: [
            // Logo Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853), // Vivid Green
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Title: KAACHA PAKKA KHATA
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900, // Extra Bold
                        height: 1.1,
                      ),
                      children: [
                        TextSpan(
                          text: 'KAACHA PAKKA ',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const TextSpan(
                          text: 'KHATA',
                          style: TextStyle(
                            color: Color(0xFF00C853), // Matching Green
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Subtitle: PREMIUM DIGITAL LEDGER
                  Text(
                    'PREMIUM DIGITAL LEDGER',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF94A3B8), // Slate 400
                      letterSpacing: 1.5, // Spaced out letters
                    ),
                  ),
                ],
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
                Consumer<AccountingModel>(
                  builder: (context, model, child) {
                    final name = model.userName;
                    return Text(
                      name != null
                          ? 'Hi, $name 👋'
                          : 'Hello there! 👋', // Added wave emoji and casual tone
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF334155), // Slate 700
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Hero Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Hero Title
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 36, // Large Hero Title
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Simplify your\n',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const TextSpan(
                            text: 'Business Accounting.',
                            style: TextStyle(
                              color: Color(0xFF00C853), // Vivid Green
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Hero Description
                    Padding(
                      padding: const EdgeInsets.only(
                          right: 40.0), // Give it some breathing room
                      child: Text(
                        'The easiest way for small businesses to track daily cash flow and generate reports.',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B), // Slate 500
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Trust Badge (Placed below as requested)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), // Light Green bg
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 16,
                            color: Color(0xFF00C853), // Eco Green Icon
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '100% SAFE & SECURE',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1B5E20), // Dark Green Text
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

                      // Use Case List with Builder to allow logic
                      Builder(
                        builder: (context) {
                          // Prepare list of items
                          final List<Map<String, dynamic>> items = [];

                          // Add standard types
                          for (var ut in UserType.values) {
                            IconData icon;
                            Color color;
                            String subtitle;

                            switch (ut) {
                              case UserType.personal:
                                icon =
                                    Icons.groups_rounded; // Family group icon
                                color = const Color(
                                    0xFF00C853); // Green (Matches Image)
                                subtitle = 'HOME EXPENSES & SAVINGS';
                                break;
                              case UserType.business:
                                icon = Icons.store_rounded;
                                color = const Color(0xFF2563EB); // Blue
                                subtitle = 'DAILY CASH FLOW & PROFITS';
                                break;
                              case UserType.institute:
                                icon = Icons.school_rounded;
                                color = const Color(0xFF7C3AED); // Purple
                                subtitle = 'FEES & STAFF SALARIES';
                                break;
                              case UserType.other:
                                icon = Icons.category_rounded;
                                color = const Color(0xFFF59E0B); // Amber
                                subtitle = 'CUSTOM LEDGER & TRACKING';
                                break;
                            }
                            items.add({
                              'id': 'standard_${ut.toString().split('.').last}',
                              'title': displayTitles[ut] ??
                                  userTypeConfigs[ut]!.name,
                              'subtitle': subtitle,
                              'icon': icon,
                              'type': 'standard',
                              'userType': ut,
                              'color': color,
                            });
                          }

                          // Palette for custom pages to ensure variety
                          final palette = [
                            const Color(0xFFEF4444), // Red
                            const Color(0xFF0891B2), // Cyan
                            const Color(0xFFDB2777), // Pink
                            const Color(0xFFEA580C), // Orange
                          ];

                          // Add custom pages
                          int customIndex = 0;
                          customPages.forEach((key, value) {
                            final colorIndex = customIndex % palette.length;
                            items.add({
                              'id': key,
                              'title': value,
                              'subtitle': 'CUSTOM TRACKING',
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
                            'subtitle': 'CREATE NEW CATEGORY',
                            'icon': Icons.add_rounded,
                            'type': 'add_new',
                            'color': const Color(0xFF94A3B8), // Neutral Gray
                          });

                          return Column(
                            children: items.map((item) {
                              final itemColor = item['color'] as Color;
                              final isAddNew = item['type'] == 'add_new';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: InkWell(
                                  onTap: () {
                                    if (isAddNew) {
                                      _showAddNewPageDialog(context);
                                    } else {
                                      _handleNavigation(item);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 20),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1F2937)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark
                                              ? Colors.black26
                                              : Colors.grey.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF374151)
                                            : Colors.grey.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Leading Icon
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: itemColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            item['icon'] as IconData,
                                            color: itemColor,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Text Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['title'] as String,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: isAddNew
                                                      ? itemColor
                                                      : (itemColor ==
                                                              const Color(
                                                                  0xFF00C853)
                                                          ? itemColor
                                                          : (isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF0F172A))),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['subtitle'] as String,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF94A3B8),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Trailing Arrow
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isAddNew
                                                ? Colors.transparent
                                                : itemColor,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: isAddNew
                                                ? Border.all(
                                                    color: itemColor, width: 2)
                                                : null,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            color: isAddNew
                                                ? itemColor
                                                : Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
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
}
