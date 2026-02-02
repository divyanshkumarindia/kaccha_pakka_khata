import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../utils/toast_utils.dart';
import '../services/recent_service.dart';
import '../state/app_state.dart';
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
                SizedBox(width: 12),
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
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (value) {
                    setDialogState(
                        () {}); // Rebuild dialog to update button state
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
                child: Text(model.t('btn_create')),
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

    // Get AppState to save the active use case
    final appState = Provider.of<AppState>(context, listen: false);

    if (type == 'custom') {
      final customTitle = item['title'];

      // Set active use case to 'Other' for custom pages
      await appState.setActiveUseCase(UserType.other);

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

      // Save the selected use case to AppState
      await appState.setActiveUseCase(ut);

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
        toolbarHeight: 90, // Increased height for three-line text
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(
                  4), // Reduced padding to make logo bigger
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1616)
                        .withValues(alpha: 0.3), // Red Glow
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/Logo Book.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            // Title and Subtitle
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Title: KAACHA PAKKA KHATA
                    Text(
                      Provider.of<AccountingModel>(context)
                          .t('app_title_1')
                          .trim(),
                      style: GoogleFonts.outfit(
                        fontSize: 18, // Reduced from 22
                        fontWeight: FontWeight.w800, // Slightly less bold
                        height: 1.1,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    // Short Name: {KPK ACCOUNTING}
                    Text(
                      Provider.of<AccountingModel>(context).t('app_short_name'),
                      style: GoogleFonts.outfit(
                        fontSize: 15, // Increased from 13
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00C853), // Matching Green
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Subtitle: PREMIUM DIGITAL LEDGER
                    Text(
                      Provider.of<AccountingModel>(context).t('app_subtitle'),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B), // Slate 500
                        letterSpacing: 0.5, // Reduced spacing
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Consumer<AccountingModel>(
            builder: (context, model, child) {
              return PopupMenuButton<String>(
                icon: Row(
                  children: [
                    Icon(Icons.language,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      model.language.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                      ),
                    ),
                  ],
                ),
                onSelected: (value) {
                  model.setLanguage(value);
                  ToastUtils.showSuccessToast(context,
                      'Language switched to ${value == 'en' ? 'English' : 'Hindi'}',
                      bottomPadding: 110.0);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'en',
                    child: Text('English'),
                  ),
                  const PopupMenuItem(
                    value: 'hi',
                    child: Text('Hindi'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                12, 24, 12, 120), // Reduced side padding (was 20)
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Consumer<AccountingModel>(
                  builder: (context, model, child) {
                    final name = model.userName;
                    final greeting = name != null
                        ? '${model.t('greeting')}, $name 👋'
                        : '${model.t('greeting_default')} 👋';
                    return Text(
                      greeting,
                      style: GoogleFonts.outfit(
                        fontSize: 20, // Middle ground (was 24 -> 18 -> 20)
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF334155), // Slate 700
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(
                    height: 16), // Balanced spacing (was 24 -> 10 -> 16)

                // Hero Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Hero Title
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 29, // Middle ground (was 33 -> 26 -> 29)
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: Provider.of<AccountingModel>(context)
                                .t('hero_title_1'),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          TextSpan(
                            text: Provider.of<AccountingModel>(context)
                                .t('hero_title_2'),
                            style: const TextStyle(
                              color: Color(0xFF00C853), // Vivid Green
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12), // Balanced spacing
                    // Hero Description
                    Padding(
                      padding: const EdgeInsets.only(
                          right:
                              30.0), // Balanced breathing room (40 -> 20 -> 30)
                      child: Text(
                        Provider.of<AccountingModel>(context)
                            .t('hero_subtitle'),
                        style: GoogleFonts.outfit(
                          fontSize: 15, // Middle ground (was 16 -> 14 -> 15)
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B), // Slate 500
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: 20), // Balanced spacing (24 -> 16 -> 20)
                    // Trust Badge (Placed below as requested)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7), // Balanced padding
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), // Light Green bg
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 15, // Balanced size
                            color: Color(0xFF00C853), // Eco Green Icon
                          ),
                          const SizedBox(width: 7),
                          Text(
                            Provider.of<AccountingModel>(context)
                                .t('badge_safe_secure'),
                            style: GoogleFonts.outfit(
                              fontSize: 11.5, // Slight tweak
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
                  padding: const EdgeInsets.all(
                      16), // Reduced internal padding (was 24)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Provider.of<AccountingModel>(context)
                            .t('section_use_case'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12), // Reduced spacing (was 20)

                      // Use Case List with Builder to allow logic
                      Builder(
                        builder: (context) {
                          final model = Provider.of<AccountingModel>(context);
                          // Prepare list of items
                          final List<Map<String, dynamic>> items = [];

                          // Add standard types
                          for (var ut in UserType.values) {
                            IconData icon;
                            Color color;
                            String subtitle;
                            String title;

                            switch (ut) {
                              case UserType.personal:
                                icon =
                                    Icons.groups_rounded; // Family group icon
                                color = const Color(0xFF00C853); // Green
                                subtitle = model.t('subtitle_personal');
                                title = model.t('card_personal');
                                break;
                              case UserType.business:
                                icon = Icons.store_rounded;
                                color = const Color(0xFF2563EB); // Blue
                                subtitle = model.t('subtitle_business');
                                title = model.t('card_business');
                                break;
                              case UserType.institute:
                                icon = Icons.school_rounded;
                                color = const Color(0xFF7C3AED); // Purple
                                subtitle = model.t('subtitle_institute');
                                title = model.t('card_institute');
                                break;
                              case UserType.other:
                                icon = Icons.category_rounded;
                                color = const Color(0xFFF59E0B); // Amber
                                subtitle = model.t('subtitle_other');
                                title = model.t('card_other');
                                break;
                            }
                            items.add({
                              'id': 'standard_${ut.toString().split('.').last}',
                              'title': title,
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
                            'title': model.t('card_add_new'),
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
                                              : Colors.grey
                                                  .withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF374151)
                                            : Colors.grey
                                                .withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Leading Icon
                                        Container(
                                          width: 45, // Reduced from 48
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: itemColor.withValues(
                                                alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            item['icon'] as IconData,
                                            color: itemColor,
                                            size: 22, // Reduced from 24
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
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isAddNew
                                                      ? itemColor
                                                      : (isDark
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF0F172A)),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['subtitle'] as String,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
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
                                          width: 38, // Reduced from 40
                                          height: 38,
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
                                            size: 19, // Reduced from 20
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
                              Provider.of<AccountingModel>(context)
                                  .t('section_recent'),
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
                const SizedBox(height: 100), // Padding for floating nav bar
              ],
            ),
          ),
        ),
      ),
    );
  }
}
