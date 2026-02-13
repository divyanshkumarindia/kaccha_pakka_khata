import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaccha_pakka_khata/services/report_service.dart';
import '../models/accounting.dart';
import 'report_viewer_screen.dart';

class CategoryReportsScreen extends StatefulWidget {
  final String categoryName;
  final String useCaseType;
  final Color categoryColor;

  const CategoryReportsScreen({
    super.key,
    required this.categoryName,
    required this.useCaseType,
    required this.categoryColor,
  });

  @override
  State<CategoryReportsScreen> createState() => _CategoryReportsScreenState();
}

class _CategoryReportsScreenState extends State<CategoryReportsScreen> {
  final ReportService _reportService = ReportService();
  final TextEditingController _searchController = TextEditingController();

  late Stream<List<Map<String, dynamic>>> _reportsStream;
  Timer? _debounce;
  bool _isDescending = true;
  String _searchQuery = '';
  DurationType? _selectedDurationFilter; // null means "All"

  final Set<String> _pendingDeleteIds = {};
  final Map<String, bool> _animatingOut = {};

  // Track expanded months (default to expanded)
  final Set<String> _collapsedMonths = {};

  @override
  void initState() {
    super.initState();
    _refreshReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _refreshReports() {
    setState(() {
      _reportsStream = _reportService.getReportsStream(
        query: _searchQuery,
        isDescending: _isDescending,
        useCaseType: widget.useCaseType,
      );
    });
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
          _refreshReports();
        });
      }
    });
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F2937)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400),
            const SizedBox(width: 8),
            const Text('Delete Report?'),
          ],
        ),
        content: const Text(
            'Are you sure you want to delete this report permanently? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reportId = report['id'].toString();
      // Animate out
      setState(() {
        _animatingOut[reportId] = true;
      });

      // Wait for animation then delete
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _pendingDeleteIds.add(reportId);
        });
        await _reportService.deleteReport(reportId);
        // Don't remove from _pendingDeleteIds - let the stream update naturally
        if (mounted) {
          setState(() {
            _animatingOut.remove(reportId);
          });
        }
      }
    }
  }

  void _openReport(Map<String, dynamic> report, DateTime? reportDate) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportViewerScreen(
          reportData: report['report_data'] ?? {},
          reportType: report['report_type'] ?? 'Normal',
          reportDate: reportDate != null
              ? DateFormat('dd MMM yyyy').format(reportDate)
              : '',
          reportId: report['id'].toString(),
        ),
      ),
    );

    // Force refresh when coming back to ensure updated data (e.g. title/date) is shown
    if (mounted) {
      _refreshReports();
    }
  }

  // Helper to extract the actual "relevant" date for grouping
  DateTime _getReportDate(Map<String, dynamic> report) {
    if (report['report_data'] != null && report['report_data'] is Map) {
      final data = report['report_data'];

      // 1. Try Period Date (Daily Reports)
      if (data['periodDate'] != null &&
          data['periodDate'].toString().isNotEmpty) {
        try {
          // Try standard format first
          return DateFormat('dd-MM-yyyy').parse(data['periodDate']);
        } catch (_) {
          try {
            // Try display format
            return DateFormat('dd MMM yyyy').parse(data['periodDate']);
          } catch (__) {}
        }
      }

      // 2. Try Period Start Date (Range Reports)
      if (data['periodStartDate'] != null &&
          data['periodStartDate'].toString().isNotEmpty) {
        try {
          return DateFormat('dd-MM-yyyy').parse(data['periodStartDate']);
        } catch (_) {}
      }

      // 3. Fallback to saved_at (Metadata)
      if (data['saved_at'] != null) {
        try {
          return DateTime.parse(data['saved_at']);
        } catch (_) {}
      }
    }

    // 4. Ultimate fallback to created_at (Cloud timestamp)
    if (report['created_at'] != null) {
      try {
        return DateTime.parse(report['created_at'].toString());
      } catch (_) {}
    }

    return DateTime.now(); // Should rarely happen
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 16, bottom: 24),
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
              child: Column(
                children: [
                  // Top Row: Back + Title + Sort
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Back Button
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 20),
                          color:
                              isDark ? Colors.white70 : const Color(0xFF64748B),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.05),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Title
                        Expanded(
                          child: Text(
                            widget.categoryName,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Sort Button (Clearer UI)
                        IconButton(
                          onPressed: () => _showSortOptions(context),
                          icon: const Icon(Icons.sort_rounded, size: 24),
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          tooltip: 'Sort Reports',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF111827)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search reports...',
                          hintStyle: GoogleFonts.inter(
                            color:
                                isDark ? Colors.white30 : Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 20,
                              color: isDark
                                  ? Colors.white30
                                  : Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _buildFilterChip(context, 'All', null),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, 'Daily', DurationType.Daily),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                            context, 'Weekly', DurationType.Weekly),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                            context, 'Monthly', DurationType.Monthly),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                            context, 'Yearly', DurationType.Yearly),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _reportsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading reports',
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                    );
                  }

                  final reports = snapshot.data ?? [];
                  var displayReports = reports
                      .where((r) =>
                          !_pendingDeleteIds.contains(r['id'].toString()))
                      .toList();

                  // Apply Duration Filter
                  if (_selectedDurationFilter != null) {
                    displayReports = displayReports.where((report) {
                      final data = report['report_data'];
                      if (data == null || data['duration'] == null)
                        return false;
                      // 'duration' is stored as index in JSON
                      return data['duration'] == _selectedDurationFilter!.index;
                    }).toList();
                  }

                  if (displayReports.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.folder_open_rounded,
                                size: 48,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedDurationFilter != null
                                ? 'No ${_selectedDurationFilter!.name} reports found'
                                : 'No reports found',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try changing the filter or create a new one.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // GROUPING LOGIC
                  // Map<MonthYear, List<Report>>
                  final Map<String, List<Map<String, dynamic>>> groupedReports =
                      {};

                  // Sort by relevant date first
                  displayReports.sort((a, b) {
                    final dateA = _getReportDate(a);
                    final dateB = _getReportDate(b);
                    // Global sort order (User preference)
                    return _isDescending
                        ? dateB.compareTo(dateA)
                        : dateA.compareTo(dateB);
                  });

                  for (var report in displayReports) {
                    final date = _getReportDate(report);
                    // Key format: "December 2025"
                    final key = DateFormat('MMMM yyyy').format(date);
                    if (!groupedReports.containsKey(key)) {
                      groupedReports[key] = [];
                    }
                    groupedReports[key]!.add(report);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                    itemCount: groupedReports.length,
                    itemBuilder: (context, index) {
                      final monthKey = groupedReports.keys.elementAt(index);
                      final monthReports = groupedReports[monthKey]!;
                      final isCollapsed = _collapsedMonths.contains(monthKey);

                      return _buildMonthGroup(
                          context, monthKey, monthReports, isDark, isCollapsed);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      BuildContext context, String label, DurationType? durationType) {
    final isSelected = _selectedDurationFilter == durationType;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get color for this specific duration type
    // For "All" (null), we use the category color or a default
    // But per requirements, we want distinct colors for the types.
    // Let's use the helper!
    Color typeColor;
    if (durationType == null) {
      typeColor = widget.categoryColor; // Keep "All" matching the category
    } else {
      typeColor = _getDurationColor(durationType);
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDurationFilter = durationType;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // Gradient for selected, plain for unselected
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    typeColor.withValues(alpha: 0.8),
                    typeColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                    ? typeColor.withValues(alpha: 0.5)
                    : typeColor.withValues(alpha: 0.3)),
            width: isSelected ? 0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? Colors.white70
                    : typeColor.withValues(
                        alpha: 0.8)), // Colored text when unselected
          ),
        ),
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1F2937)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort Reports',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOption(
                context,
                title: 'Newest First',
                isSelected: _isDescending,
                onTap: () {
                  setState(() {
                    _isDescending = true;
                    _refreshReports();
                  });
                  Navigator.pop(context);
                },
                isDark: isDark,
              ),
              _buildSortOption(
                context,
                title: 'Oldest First',
                isSelected: !_isDescending,
                onTap: () {
                  setState(() {
                    _isDescending = false;
                    _refreshReports();
                  });
                  Navigator.pop(context);
                },
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(BuildContext context,
      {required String title,
      required bool isSelected,
      required VoidCallback onTap,
      required bool isDark}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? widget.categoryColor
              : (isDark ? Colors.white70 : Colors.grey.shade700),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: widget.categoryColor)
          : null,
    );
  }

  Widget _buildMonthGroup(
    BuildContext context,
    String monthTitle,
    List<Map<String, dynamic>> reports,
    bool isDark,
    bool isCollapsed,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header (Clickable to toggle)
          InkWell(
            onTap: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedMonths.remove(monthTitle);
                } else {
                  _collapsedMonths.add(monthTitle);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: widget.categoryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    monthTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 18, // Bigger font for visibility
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${reports.length})',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 24,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Reports List (Animated collapse)
          AnimatedCrossFade(
            firstChild: Container(), // Collapsed state
            secondChild: Column(
              children: reports
                  .map((report) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPremiumReportCard(context, report, isDark),
                      ))
                  .toList(),
            ),
            crossFadeState: isCollapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumReportCard(
      BuildContext context, Map<String, dynamic> report, bool isDark) {
    final reportId = report['id'].toString();
    final isAnimatingOut = _animatingOut[reportId] ?? false;

    // Use refined date logic
    // Use refined date logic for sorting/grouping if needed, but for "Saved:", use actual timestamp
    final reportDate = _getReportDate(report);
    final savedDate = _getSavedTimestamp(report);
    final displayDate = DateFormat('dd MMM yyyy').format(savedDate);
    final displayTime = DateFormat('hh:mm a').format(savedDate);

    String title = report['report_data']?['pageTitle'] ?? 'View Balance Report';

    String durationText = _getDurationText(report);

    // Card Style Logic
    final mainColor = widget.categoryColor;

    return AnimatedSlide(
      offset: isAnimatingOut ? const Offset(1.0, 0.0) : Offset.zero,
      duration: const Duration(milliseconds: 300),
      child: AnimatedOpacity(
        opacity: isAnimatingOut ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(20), // Slightly smaller radius
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : mainColor.withValues(alpha: 0.05), // Softer shadow
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openReport(report, reportDate),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12), // Reduced padding (was 20)
                child: Row(
                  children: [
                    // Premium Icon Box (Smaller)
                    Container(
                      width: 44, // Reduced from 56
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            mainColor.withValues(alpha: 0.1),
                            mainColor.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: mainColor.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: mainColor,
                        size: 22, // Reduced from 26
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 15, // Slightly smaller font
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Duration and Period Row
                          Row(
                            children: [
                              // Duration Tag
                              if (durationText != 'Report') ...[
                                Builder(builder: (context) {
                                  // Determine type for color
                                  DurationType? type;
                                  if (durationText == 'Daily')
                                    type = DurationType.Daily;
                                  if (durationText == 'Weekly')
                                    type = DurationType.Weekly;
                                  if (durationText == 'Monthly')
                                    type = DurationType.Monthly;
                                  if (durationText == 'Yearly')
                                    type = DurationType.Yearly;

                                  final typeColor = _getDurationColor(type);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? typeColor.withValues(alpha: 0.15)
                                          : typeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: typeColor.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      durationText,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: typeColor, // Colored text
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 8),
                              ],
                              // Period Details
                              Expanded(
                                child: Text(
                                  _getReportPeriodDetails(report),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Saved Date Row (Smaller)
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                'Saved: $displayDate • $displayTime',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action Buttons
                    const SizedBox(width: 4),
                    // Delete Button
                    IconButton(
                      onPressed: () => _confirmAndDelete(report),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: Colors.red.shade300,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(6), // Reduced padding
                        backgroundColor: Colors.transparent,
                      ),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getDurationColor(DurationType? type) {
    if (type == null) return const Color(0xFF64748B); // Slate (All)
    switch (type) {
      case DurationType.Daily:
        return const Color(0xFF3B82F6); // Blue
      case DurationType.Weekly:
        return const Color(0xFF8B5CF6); // Violet
      case DurationType.Monthly:
        return const Color(0xFFF59E0B); // Amber
      case DurationType.Yearly:
        return const Color(0xFFEC4899); // Pink
    }
  }

  String _getDurationText(Map<String, dynamic> report) {
    if (report['report_data'] != null &&
        report['report_data']['duration'] != null) {
      try {
        final durationIndex = report['report_data']['duration'] as int;
        if (durationIndex >= 0 && durationIndex < DurationType.values.length) {
          final type = DurationType.values[durationIndex];
          switch (type) {
            case DurationType.Daily:
              return 'Daily';
            case DurationType.Weekly:
              return 'Weekly';
            case DurationType.Monthly:
              return 'Monthly';
            case DurationType.Yearly:
              return 'Yearly';
          }
        }
      } catch (_) {}
    }
    return 'Report';
  }

  String _getReportPeriodDetails(Map<String, dynamic> report) {
    if (report['report_data'] == null) return '';
    final data = report['report_data'];

    if (data['duration'] != null) {
      try {
        final durationIndex = data['duration'] as int;
        if (durationIndex >= 0 && durationIndex < DurationType.values.length) {
          final type = DurationType.values[durationIndex];
          switch (type) {
            case DurationType.Daily:
              return data['periodDate'] ?? '';
            case DurationType.Weekly:
              final start = data['periodStartDate'] ?? '';
              final end = data['periodEndDate'] ?? '';
              if (start.isEmpty || end.isEmpty) return 'No range selected';
              return '$start - $end';
            case DurationType.Monthly:
              return data['periodDate'] ?? '';
            case DurationType.Yearly:
              final start = data['periodStartDate'] ?? '';
              final end = data['periodEndDate'] ?? '';
              if (start.isNotEmpty && end.isNotEmpty) {
                return '$start - $end';
              }
              return data['periodDate'] ?? '';
          }
        }
      } catch (_) {}
    }
    return '';
  }

  DateTime _getSavedTimestamp(Map<String, dynamic> report) {
    // 1. Try saved_at from report_data (client-side timestamp when saved)
    if (report['report_data'] != null && report['report_data'] is Map) {
      final data = report['report_data'];
      if (data['saved_at'] != null) {
        try {
          return DateTime.parse(data['saved_at']);
        } catch (_) {}
      }
    }

    // 2. Try created_at from Supabase metadata
    if (report['created_at'] != null) {
      try {
        return DateTime.parse(report['created_at'].toString());
      } catch (_) {}
    }

    return DateTime.now();
  }
}
