import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:my_daily_balance_flutter/services/report_service.dart';
import 'package:my_daily_balance_flutter/state/accounting_model.dart';
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

  final Set<String> _pendingDeleteIds = {};
  final Map<String, bool> _animatingOut = {};
  Timer? _pendingDeleteTimer;
  Map<String, dynamic>? _pendingDeleteReport;

  @override
  void initState() {
    super.initState();
    _refreshReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _pendingDeleteTimer?.cancel();
    super.dispose();
  }

  void _refreshReports() {
    final model = Provider.of<AccountingModel>(context, listen: false);

    setState(() {
      _reportsStream = _reportService
          .getReportsStream(
        query: _searchQuery,
        isDescending: _isDescending,
        useCaseType: widget.useCaseType,
      )
          .map((cloudReports) {
        // 1. Get local reports from AccountingModel
        final localReports = model.savedReports.where((r) {
          if (r['use_case_type'] != widget.useCaseType) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final title = (r['title'] ?? '').toString().toLowerCase();
            final date =
                (r['report_date'] ?? r['date'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            if (!title.contains(q) && !date.contains(q)) return false;
          }
          return true;
        }).toList();

        // 2. Merge and De-duplicate
        final merged = [...cloudReports];
        for (var lr in localReports) {
          if (!merged.any((cr) => cr['id'] == lr['id'])) {
            merged.add(lr);
          }
        }

        // 3. Sort
        merged.sort((a, b) {
          final dateAString =
              a['report_date'] ?? a['savedAt'] ?? a['date'] ?? '';
          final dateBString =
              b['report_date'] ?? b['savedAt'] ?? b['date'] ?? '';

          final dateA = DateTime.tryParse(dateAString) ?? DateTime(0);
          final dateB = DateTime.tryParse(dateBString) ?? DateTime(0);

          return _isDescending
              ? dateB.compareTo(dateA)
              : dateA.compareTo(dateB);
        });

        return merged;
      });
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

  void _deleteReport(Map<String, dynamic> report) {
    final reportId = report['id'].toString();
    _pendingDeleteTimer?.cancel();

    setState(() {
      _animatingOut[reportId] = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _pendingDeleteReport = report;
          _pendingDeleteIds.add(reportId);
          _animatingOut.remove(reportId);
        });
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Report Deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: _undoDelete,
        ),
      ),
    );

    _pendingDeleteTimer = Timer(const Duration(seconds: 4), () async {
      if (mounted && _pendingDeleteIds.contains(reportId)) {
        try {
          await _reportService.deleteReport(reportId);
          if (mounted) {
            setState(() {
              _pendingDeleteIds.remove(reportId);
              if (_pendingDeleteReport == report) {
                _pendingDeleteReport = null;
              }
            });
          }
        } catch (e) {
          if (mounted) {
            _undoDelete();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete report: $e')),
            );
          }
        }
      }
    });
  }

  void _undoDelete() {
    _pendingDeleteTimer?.cancel();
    if (_pendingDeleteReport != null) {
      final reportId = _pendingDeleteReport!['id'].toString();
      setState(() {
        _pendingDeleteIds.remove(reportId);
        _pendingDeleteReport = null;
      });
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isDescending = !_isDescending;
                _refreshReports();
              });
            },
            icon: Icon(
              _isDescending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search within ${widget.categoryName}...',
                hintStyle: GoogleFonts.outfit(
                    color: isDark ? Colors.white30 : Colors.grey),
                prefixIcon: Icon(Icons.search,
                    color: isDark ? Colors.white70 : Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: widget.categoryColor, width: 2),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _reportsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading reports'));
                }

                final reports = snapshot.data ?? [];
                final displayReports = reports
                    .where(
                        (r) => !_pendingDeleteIds.contains(r['id'].toString()))
                    .toList();

                if (displayReports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open,
                            size: 64,
                            color: isDark ? Colors.white24 : Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No reports found in this category',
                          style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayReports.length,
                  itemBuilder: (context, index) {
                    final report = displayReports[index];
                    return _buildDismissibleReportCard(context, report, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleReportCard(
      BuildContext context, Map<String, dynamic> report, bool isDark) {
    final reportId = report['id'].toString();
    final isAnimatingOut = _animatingOut[reportId] ?? false;

    return AnimatedSlide(
      offset: isAnimatingOut ? const Offset(-1.0, 0.0) : Offset.zero,
      duration: const Duration(milliseconds: 300),
      child: Slidable(
        key: Key(reportId),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => _deleteReport(report),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: _buildReportCard(context, report, isDark),
      ),
    );
  }

  Widget _buildReportCard(
      BuildContext context, Map<String, dynamic> report, bool isDark) {
    DateTime? reportDate;
    String displayDate = 'Unknown Date';

    final rawDate = report['report_date'] ?? report['date'];
    if (rawDate != null) {
      reportDate = DateTime.tryParse(rawDate.toString());
      if (reportDate != null) {
        displayDate =
            DateFormat('dd MMM yyyy, hh:mm a').format(reportDate.toLocal());
      } else {
        displayDate = rawDate.toString();
      }
    }

    String title = report['report_data']?['pageTitle'] ?? 'View Balance Report';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.analytics_outlined, color: widget.categoryColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          displayDate,
          style: TextStyle(
              fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
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
        },
      ),
    );
  }
}
