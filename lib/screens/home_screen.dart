import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../services/recent_service.dart';
import 'accounting_template_screen.dart';

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
            backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF6366F1)),
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
                    color: isDark ? Color(0xFF9CA3AF) : Color(0xFF6B7280),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF374151)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF6366F1), width: 2),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFF9FAFB),
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
                child: Text(
                  'Cancel',
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
                        String pageName = controller.text.trim();
                        Navigator.pop(context);
                        _createAndNavigateToCustomPage(pageName);
                      }
                    : null, // Disable if no text
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                  disabledForegroundColor: isDark
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF9CA3AF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Kaccha-Pakka Khata',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF27272A) : Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Color.fromRGBO(99, 102, 241, 0.2)
                        : const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF6366F1),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Receipts & Payments Tracker',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 32),

                // Main Card
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                      const SizedBox(height: 16),

                      // Dropdown with Add New button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3F3F46)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF52525B)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedPageId,
                                hint: Text(
                                  'Choose...',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFA1A1AA)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                isExpanded: true,
                                icon: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: isDark
                                      ? const Color(0xFFA1A1AA)
                                      : const Color(0xFF64748B),
                                ),
                                dropdownColor: isDark
                                    ? const Color(0xFF3F3F46)
                                    : Colors.white,
                                items: [
                                  // Standard page types
                                  ...UserType.values.map((ut) {
                                    final pageId =
                                        'standard_${ut.toString().split('.').last}';
                                    return DropdownMenuItem<String>(
                                      value: pageId,
                                      child: Text(
                                        displayTitles[ut] ??
                                            userTypeConfigs[ut]!.name,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  // Custom pages
                                  ...customPages.entries.map((entry) {
                                    return DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 16,
                                            color: Color(0xFF6366F1),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              entry.value,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() {
                                    selectedPageId = val;
                                    if (val.startsWith('standard_')) {
                                      // Standard page
                                      final typeName =
                                          val.replaceFirst('standard_', '');
                                      selectedUseCase =
                                          UserType.values.firstWhere(
                                        (ut) =>
                                            ut.toString().split('.').last ==
                                            typeName,
                                      );
                                      selectedCustomPageId = null;
                                      description =
                                          descriptions[selectedUseCase] ??
                                              'Description will appear here';
                                    } else {
                                      // Custom page
                                      selectedCustomPageId = val;
                                      selectedUseCase = null;
                                      description =
                                          'Your custom accounting page: ${customPages[val]}';
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Add New Page Button
                          OutlinedButton.icon(
                            onPressed: () => _showAddNewPageDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add New Accounting Page'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(
                                color: Color(0xFF6366F1),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF3F3F46)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedPageId == null
                              ? null
                              : () async {
                                  if (selectedCustomPageId != null) {
                                    // Create a new model with UserType.other for custom pages
                                    final customModel = AccountingModel(
                                        userType: UserType.other);
                                    await customModel.loadFromPrefs();

                                    // Navigate to custom page with its own model
                                    final wasDeleted = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ChangeNotifierProvider<
                                                AccountingModel>.value(
                                          value: customModel,
                                          child: AccountingTemplateScreen(
                                            templateKey: 'other',
                                            customTitle: customPages[
                                                selectedCustomPageId],
                                            customPageId: selectedCustomPageId,
                                          ),
                                        ),
                                      ),
                                    );
                                    await _loadCustomPages();

                                    // If page was deleted, reset selection
                                    if (wasDeleted == true) {
                                      setState(() {
                                        selectedPageId = null;
                                      });
                                    }
                                  } else if (selectedUseCase != null) {
                                    // Navigate to standard page
                                    final model = AccountingModel(
                                        userType: selectedUseCase!);
                                    await model.loadFromPrefs();
                                    String route = '/accounting';
                                    switch (selectedUseCase!) {
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
                                    await Navigator.pushNamed(context, route,
                                        arguments: model);
                                    await _loadPageTitles();
                                  }
                                  await _loadRecents();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continue to Accounting',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Recent Pages Section
                if (_recents.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Pages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
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
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                tileColor: isDark
                                    ? const Color(0xFF3F3F46)
                                    : const Color(0xFFF1F5F9),
                                leading: Icon(
                                  Icons.history,
                                  color: const Color(0xFF6366F1),
                                ),
                                title: Text(
                                  recent.displayTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  userTypeConfigs[userType]!.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFFA1A1AA)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: isDark
                                      ? const Color(0xFFA1A1AA)
                                      : const Color(0xFF64748B),
                                ),
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
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // Features Section
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Track\nReceipts',
                        isDark: isDark,
                      ),
                      _buildFeatureItem(
                        icon: Icons.payments_outlined,
                        label: 'Track\nPayments',
                        isDark: isDark,
                      ),
                      _buildFeatureItem(
                        icon: Icons.assessment_outlined,
                        label: 'Detailed\nReports',
                        isDark: isDark,
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
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFF6366F1),
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
