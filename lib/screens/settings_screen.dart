import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<UserType, String> displayTitles = {};
  Map<String, String> customPages = {}; // Store custom pages

  @override
  void initState() {
    super.initState();
    _loadPageTitles();
    _loadCustomPages();
  }

  Future<void> _loadPageTitles() async {
    // Initialize with defaults
    for (var ut in UserType.values) {
      displayTitles[ut] = userTypeConfigs[ut]!.name;
    }
    // Load saved overrides
    for (var ut in UserType.values) {
      final saved = await AccountingModel.loadSavedPageTitle(ut);
      if (saved != null && saved.isNotEmpty) {
        displayTitles[ut] = saved;
      }
    }
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final model = Provider.of<AccountingModel>(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9), // Match Home BG
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header (Matches Saved Reports)
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
                            'Settings',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Manage your preferences and app settings.',
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
                        Icons.settings_suggest_rounded,
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

            // Settings Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Account Settings
                  _buildSectionHeader(
                      model.t('sec_account'), Icons.person_rounded, isDark),
                  _buildSettingsCard(
                    isDark,
                    [
                      _buildSettingTile(
                        context,
                        model.t('label_profile'),
                        model.userName ?? model.t('hint_set_name'),
                        Icons.badge_rounded,
                        const Color(0xFF3B82F6), // Blue
                        () => _showNameEditDialog(context, model),
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSettingTile(
                        context,
                        'Home Page Layout',
                        'Reorder use cases on home screen',
                        Icons.dashboard_customize_rounded,
                        const Color(0xFF8B5CF6), // Purple
                        () => _showHomePageLayoutDialog(context, model),
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Appearance
                  _buildSectionHeader(
                      model.t('sec_appearance'), Icons.palette_rounded, isDark),
                  _buildSettingsCard(
                    isDark,
                    [
                      _buildSettingTile(
                        context,
                        model.t('label_theme'),
                        _getThemeModeLabel(model.themeMode),
                        Icons.brightness_6_rounded,
                        const Color(0xFFF59E0B), // Amber
                        () => _showThemeModeDialog(context, model),
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSettingTile(
                        context,
                        model.t('label_font_size'),
                        model.t('desc_font_size'),
                        Icons.text_fields_rounded,
                        const Color(0xFF10B981), // Emerald
                        () => _showComingSoonSnackBar(context),
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Data Management
                  _buildSectionHeader(
                      model.t('sec_data'), Icons.storage_rounded, isDark),
                  _buildSettingsCard(
                    isDark,
                    [
                      _buildSettingTile(
                        context,
                        model.t('label_backup'),
                        model.t('desc_backup'),
                        Icons.cloud_upload_rounded,
                        const Color(0xFF0EA5E9), // Sky
                        () => _showBackupDialog(context, model),
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSettingTile(
                        context,
                        model.t('label_restore'),
                        model.t('desc_restore'),
                        Icons.settings_backup_restore_rounded,
                        const Color(0xFF6366F1), // Indigo
                        () => _showRestoreDialog(context, model),
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSettingTile(
                        context,
                        model.t('label_export'),
                        model.t('desc_export'),
                        Icons.file_download_rounded,
                        const Color(0xFFEC4899), // Pink
                        () => _showComingSoonSnackBar(context),
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSettingTile(
                        context,
                        model.t('label_clear_data'),
                        model.t('desc_clear_data'),
                        Icons.delete_forever_rounded,
                        const Color(0xFFEF4444), // Red
                        () => _showClearDataDialog(context, model),
                        isDark,
                        isDestructive: true,
                        customIconColor: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Report Settings
                  _buildSectionHeader(
                      model.t('sec_reports'), Icons.article_rounded, isDark),
                  _buildSettingsCard(
                    isDark,
                    [
                      _buildSwitchTile(
                        model.t('label_auto_save'),
                        model.t('desc_auto_save'),
                        Icons.save_rounded,
                        const Color(0xFF14B8A6), // Teal
                        model.autoSaveReports,
                        (value) => model.toggleAutoSaveReports(),
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSettingTile(
                        context,
                        model.t('label_report_format'),
                        model.defaultReportFormat ?? 'Basic',
                        Icons.format_list_bulleted_rounded,
                        const Color(0xFFF97316), // Orange
                        () => _showReportFormatDialog(context, model),
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // About & Danger Zone
                  _buildSectionHeader(
                      model.t('sec_about'), Icons.info_rounded, isDark),
                  _buildSettingsCard(
                    isDark,
                    [
                      _buildInfoTile(
                        model.t('label_app_version'),
                        '1.0.0',
                        Icons.verified_rounded,
                        const Color(0xFF8B5CF6),
                        isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSettingTile(
                        context,
                        model.t('label_developer'),
                        'Divyansh Kumar',
                        Icons.code_rounded,
                        const Color(0xFF64748B),
                        () => _showDeveloperInfo(context),
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSettingsCard(
                    isDark,
                    [
                      _buildSettingTile(
                        context,
                        model.t('label_logout'),
                        model.t('desc_logout'),
                        Icons.logout_rounded,
                        const Color(0xFFEF4444),
                        () => _handleLogout(context),
                        isDark,
                        isDestructive: true,
                        customIconColor: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20), // Premium Radius
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
    bool isDark, {
    bool isDestructive = false,
    Color? customIconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Icon Box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (customIconColor ?? iconColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: customIconColor ?? iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? (const Color(0xFFEF4444))
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDestructive
                            ? Colors.red.withValues(alpha: 0.7)
                            : (isDark
                                ? Colors.white54
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: iconColor,
            inactiveThumbColor: isDark ? Colors.grey.shade400 : Colors.white,
            inactiveTrackColor:
                isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
      String title, String value, IconData icon, Color iconColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.2), // Increased visibility
      indent: 64, // Align with text start (Icon size + padding)
    );
  }

  void _showNameEditDialog(BuildContext context, AccountingModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: model.userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          model.t('dialog_edit_name'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: model.t('hint_enter_name'),
            hintStyle: GoogleFonts.inter(
                color: isDark ? Colors.white38 : Colors.black38),
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
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              model.t('btn_cancel'),
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              model.setUserName(controller.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(model.t('btn_save'), style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  // Dialog Functions
  void _showHomePageLayoutDialog(
      BuildContext context, AccountingModel model) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reload custom pages to ensure we have the latest list
    await _loadCustomPages();

    // Combine standard and custom pages into a single list
    List<Map<String, dynamic>> allItems = [];

    // 1. Get current order from model or fallback to default
    List<String> currentOrder = List.from(model.homePageOrder);

    // 2. Identify all available page IDs
    List<String> availableIds = [];
    UserType.values.forEach((ut) {
      String value = ut.toString().split('.').last;
      String typeValue = value[0].toUpperCase() + value.substring(1);
      availableIds.add(typeValue);
    });
    availableIds.addAll(customPages.keys);

    // 3. Sync: If order is empty or missing items, re-initialize
    if (currentOrder.isEmpty) {
      currentOrder = List.from(availableIds);
    } else {
      // Add any new items that aren't in the saved order
      for (var id in availableIds) {
        if (!currentOrder.contains(id)) {
          currentOrder.add(id);
        }
      }
      // Remove any items that no longer exist (e.g. deleted custom pages)
      currentOrder.removeWhere((id) => !availableIds.contains(id));
    }

    // 4. Build the display list based on the final order
    for (var id in currentOrder) {
      String displayName = '';
      bool isCustom = false;

      // Check if it's a standard type
      final stdTypeIndex = UserType.values.indexWhere((ut) {
        String val = ut.toString().split('.').last;
        String typeVal = val[0].toUpperCase() + val.substring(1);
        return typeVal == id;
      });

      if (stdTypeIndex != -1) {
        final userType = UserType.values[stdTypeIndex];
        displayName =
            displayTitles[userType] ?? userTypeConfigs[userType]!.name;
      } else if (customPages.containsKey(id)) {
        displayName = customPages[id]!;
        isCustom = true;
      } else {
        continue; // Skip if unknown
      }

      allItems.add({
        'id': id,
        'display': displayName,
        'isCustom': isCustom,
      });
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor:
                    isDark ? const Color(0xFF1F2937) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                title: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Home Page Layout',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                        )),
                    const SizedBox(height: 8),
                    Text(
                      'Drag to reorder content',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      Expanded(
                        child: ReorderableListView(
                          proxyDecorator: (child, index, animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (BuildContext context, Widget? child) {
                                return Material(
                                  elevation: 8,
                                  shadowColor: Colors.black26,
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Transform.scale(
                                    scale: 1.02,
                                    child: child,
                                  ),
                                );
                              },
                              child: child,
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              final item = allItems.removeAt(oldIndex);
                              allItems.insert(newIndex, item);
                            });
                          },
                          children: [
                            for (int index = 0;
                                index < allItems.length;
                                index++)
                              Container(
                                key: ValueKey(allItems[index]['id']),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black26
                                          : Colors.grey.shade200,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : const Color.fromARGB(
                                            255, 233, 232, 232),
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: (allItems[index]['isCustom']
                                                as bool)
                                            ? [
                                                const Color(
                                                    0xFF6366F1), // Indigo
                                                const Color(0xFF818CF8),
                                              ]
                                            : [
                                                const Color(0xFF3B82F6), // Blue
                                                const Color(0xFF60A5FA),
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (allItems[index]['isCustom']
                                                  as bool)
                                              ? const Color(0xFF6366F1)
                                                  .withValues(alpha: 0.3)
                                              : const Color(0xFF3B82F6)
                                                  .withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      (allItems[index]['isCustom'] as bool)
                                          ? Icons.star_rounded
                                          : Icons.grid_view_rounded,
                                      size: 21,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    allItems[index]['display'] as String,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  trailing: ReorderableDragStartListener(
                                    index: index,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.05)
                                            : const Color(0xFFF8F8F8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            model.t('btn_cancel'),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white60
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final newOrder = allItems
                                .map((item) => item['id'] as String)
                                .toList();
                            model.setHomePageOrder(newOrder);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 4,
                            shadowColor:
                                const Color(0xFF2563EB).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            model.t('btn_save'),
                            style:
                                GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  void _showReportFormatDialog(BuildContext context, AccountingModel model) {
    final formats = ['Basic', 'Detailed'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Default Report Format',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: formats.map((format) {
            final isSelected = (model.defaultReportFormat ?? 'Basic') == format;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFF97316)
                      : (isDark ? Colors.white10 : Colors.grey.shade300),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  model.setDefaultReportFormat(format);
                  Navigator.pop(context);
                },
                leading: Radio<String>(
                  value: format,
                  // ignore: deprecated_member_use
                  groupValue: model.defaultReportFormat ?? 'Basic',
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    model.setDefaultReportFormat(value!);
                    Navigator.pop(context);
                  },
                  activeColor: const Color(0xFFF97316),
                ),
                title: Text(format,
                    style: GoogleFonts.inter(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context, AccountingModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(model.t('dialog_backup_title'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(model.t('dialog_backup_msg'), style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              model.t('btn_cancel'),
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              model.backupData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(model.t('msg_backup_success'),
                      style: GoogleFonts.inter()),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(model.t('btn_backup'), style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, AccountingModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(model.t('dialog_restore_title'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content:
            Text(model.t('dialog_restore_msg'), style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              model.t('btn_cancel'),
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              model.restoreData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(model.t('msg_restore_success'),
                      style: GoogleFonts.inter()),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(model.t('btn_restore'), style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, AccountingModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(model.t('dialog_clear_title'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(model.t('dialog_clear_msg'), style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              model.t('btn_cancel'),
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              model.clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(model.t('msg_clear_success'),
                      style: GoogleFonts.inter()),
                  backgroundColor: const Color(0xFFEF4444),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(model.t('btn_delete_all'), style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  void _showDeveloperInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.code_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 12),
            Text('Developer Info',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kaccha Pakka Khata',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: GoogleFonts.inter(
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Developed by:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Divyansh Kumar',
              style: GoogleFonts.inter(
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: GoogleFonts.outfit(color: const Color(0xFF10B981))),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Coming Soon!', style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFF1F2937),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show confirmation dialog logic (reused from Auth logic usually, but simplified here)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(
                    color: isDark ? Colors.white60 : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Logout', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  // Helper to interpret theme mode
  String _getThemeModeLabel(String mode) {
    switch (mode) {
      case 'system':
        return 'System Default';
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  void _showThemeModeDialog(BuildContext context, AccountingModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Choose Theme',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
                context, 'System Default', 'system', model.themeMode, (val) {
              model.setThemeMode(val);
              Navigator.pop(context);
            }),
            _buildThemeOption(context, 'Light', 'light', model.themeMode,
                (val) {
              model.setThemeMode(val);
              Navigator.pop(context);
            }),
            _buildThemeOption(context, 'Dark', 'dark', model.themeMode, (val) {
              model.setThemeMode(val);
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, String value,
      String current, Function(String) onTap) {
    final isSelected = value == current;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFF59E0B)
              : (isDark ? Colors.white10 : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        title: Text(title,
            style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFFF59E0B))
            : null,
        onTap: () => onTap(value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
