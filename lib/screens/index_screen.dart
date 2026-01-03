import 'package:flutter/material.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../services/recent_service.dart';
import '../config/accounting_templates.dart';
// Note: intentionally not importing subscription_plans or theme to keep this file focused on UI only

class IndexScreen extends StatefulWidget {
  const IndexScreen({Key? key}) : super(key: key);

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  UserType? selectedUseCase;
  String description = 'Description will appear here';

  // display titles for dropdown; can be overridden by user-saved values
  final Map<UserType, String> displayTitles = {};

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
    _loadRecents();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header
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
                Text(
                  'My Kaccha-Pakka Khata',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
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
                      const SizedBox(height: 24),

                      // Dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF27272A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF3F3F46)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UserType>(
                            isExpanded: true,
                            value: selectedUseCase,
                            hint: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Choose your use case...',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            icon: const Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: Icon(Icons.keyboard_arrow_down, size: 24),
                            ),
                            dropdownColor:
                                isDark ? const Color(0xFF27272A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            items: UserType.values.map((ut) {
                              final cfg = userTypeConfigs[ut]!;
                              final label = displayTitles[ut] ?? cfg.name;
                              return DropdownMenuItem(
                                value: ut,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedUseCase = value;
                                if (value != null &&
                                    descriptions.containsKey(value)) {
                                  description = descriptions[value]!;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF27272A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedUseCase == null
                              ? null
                              : () async {
                                  final model = AccountingModel(
                                      userType: selectedUseCase!);
                                  await model.loadFromPrefs();
                                  String route =
                                      '/main'; // Navigate to main navigation with bottom nav

                                  // Store the selected route for reference
                                  switch (selectedUseCase!) {
                                    case UserType.personal:
                                      // route = '/accounting/family';
                                      break;
                                    case UserType.business:
                                      // route = '/accounting/business';
                                      break;
                                    case UserType.institute:
                                      // route = '/accounting/institute';
                                      break;
                                    case UserType.other:
                                      // route = '/accounting/other';
                                      break;
                                  }
                                  // await navigation so we can refresh titles when returning
                                  await Navigator.pushNamed(context, route,
                                      arguments: model);
                                  await _loadPageTitles();
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
                const SizedBox(height: 32),

                // Recent Snapshots
                if (_recents.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Snapshots',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: _recents.map((r) {
                        final tpl = defaultTemplates[r.templateKey];
                        final dt =
                            DateTime.fromMillisecondsSinceEpoch(r.timestamp);
                        return Card(
                          child: ListTile(
                            title: Text(r.displayTitle),
                            subtitle: Text(
                                '${tpl?.friendlyName ?? r.templateKey} • ${dt.toLocal()}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    // restore and open
                                    final ut =
                                        _userTypeForTemplate(r.templateKey);
                                    final model = AccountingModel(userType: ut);
                                    // apply snapshot fields
                                    final st = r.state;
                                    model.pageTitle =
                                        (st['pageTitle'] ?? '') as String?;
                                    model.periodDate =
                                        (st['periodDate'] ?? '') as String;
                                    model.periodStartDate =
                                        (st['periodStartDate'] ?? '') as String;
                                    model.periodEndDate =
                                        (st['periodEndDate'] ?? '') as String;
                                    final route =
                                        _routeForTemplate(r.templateKey);
                                    await Navigator.pushNamed(context, route,
                                        arguments: model);
                                    await _loadPageTitles();
                                    await _loadRecents();
                                  },
                                  child: const Text('Open'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await RecentService.deleteRecent(r.id);
                                    await _loadRecents();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Footer Features
                Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureItem(
                        icon: Icons.track_changes_outlined,
                        label: 'Easy Tracking',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFeatureItem(
                        icon: Icons.widgets_outlined,
                        label: 'Multiple\nModes',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
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
