import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_daily_balance_flutter/services/report_service.dart';
import 'package:my_daily_balance_flutter/theme.dart';
import 'report_viewer_screen.dart';

class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() => _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  final ReportService _reportService = ReportService();
  final TextEditingController _searchController = TextEditingController();
  bool _isDescending = true;
  String _searchQuery = '';

  // Local state for optimistic UI updates
  List<Map<String, dynamic>> _localReports = [];
  bool _hasPendingDelete = false;
  Timer? _pendingDeleteTimer;
  Map<String, dynamic>? _pendingDeleteReport;
  int? _pendingDeleteIndex;

  @override
  void dispose() {
    _searchController.dispose();
    _pendingDeleteTimer?.cancel();
    super.dispose();
  }

  void _deleteReport(Map<String, dynamic> report, int index) {
    // Cancel any existing pending delete
    _pendingDeleteTimer?.cancel();

    setState(() {
      _hasPendingDelete = true;
      _pendingDeleteReport = report;
      _pendingDeleteIndex = index;
      _localReports.removeAt(index);
    });

    // Show SnackBar with Undo option
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Report Deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: _undoDelete,
        ),
      ),
    );

    // Start timer to actually delete after 5 seconds
    _pendingDeleteTimer = Timer(const Duration(seconds: 5), () async {
      if (_pendingDeleteReport != null) {
        try {
          await _reportService
              .deleteReport(_pendingDeleteReport!['id'].toString());
        } catch (e) {
          // If delete fails, restore the item
          if (mounted) {
            _undoDelete();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete report: $e')),
            );
          }
        }
        _clearPendingDelete();
      }
    });
  }

  void _undoDelete() {
    _pendingDeleteTimer?.cancel();
    if (_pendingDeleteReport != null && _pendingDeleteIndex != null) {
      setState(() {
        // Re-insert at original position, clamping to valid range
        final insertIndex = _pendingDeleteIndex!.clamp(0, _localReports.length);
        _localReports.insert(insertIndex, _pendingDeleteReport!);
      });
    }
    _clearPendingDelete();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _clearPendingDelete() {
    _pendingDeleteTimer = null;
    _pendingDeleteReport = null;
    _pendingDeleteIndex = null;
    if (mounted) {
      setState(() {
        _hasPendingDelete = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Saved Reports'),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isDescending = !_isDescending;
              });
            },
            icon: Icon(
              _isDescending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            tooltip: _isDescending ? 'Newest First' : 'Oldest First',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by type or date...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Reports List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _reportService.getReportsStream(
                query: _searchQuery,
                isDescending: _isDescending,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading reports',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  );
                }

                final reports = snapshot.data ?? [];

                // Sync local state with stream (only when no pending delete)
                if (!_hasPendingDelete) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_hasPendingDelete) {
                      setState(() {
                        _localReports = List.from(reports);
                      });
                    }
                  });
                }

                if (_localReports.isEmpty && reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 64,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matching reports found'
                              : 'No saved reports yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Use local reports for display
                final displayReports =
                    _localReports.isNotEmpty ? _localReports : reports;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: displayReports.length,
                  itemBuilder: (context, index) {
                    final report = displayReports[index];
                    return _buildDismissibleReportCard(
                        context, report, index, isDark);
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
    BuildContext context,
    Map<String, dynamic> report,
    int index,
    bool isDark,
  ) {
    return Dismissible(
      key: Key(report['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteReport(report, index),
      child: _buildReportCard(context, report, isDark),
    );
  }

  Widget _buildReportCard(
      BuildContext context, Map<String, dynamic> report, bool isDark) {
    // Safely parse dates
    DateTime? reportDate;
    if (report['report_date'] != null) {
      reportDate = DateTime.tryParse(report['report_date']);
    }

    final type = report['report_type'] ?? 'Report';

    // Attempt to extract title from JSONB if available or use generic
    String title = '$type Report';
    if (report['report_data'] != null &&
        report['report_data']['pageTitle'] != null) {
      title = report['report_data']['pageTitle'];
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.analytics_outlined,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reportDate != null
                        ? DateFormat('dd MMM yyyy, hh:mm a')
                            .format(reportDate.toLocal())
                        : 'Unknown Date',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportViewerScreen(
                      reportData: report['report_data'] ?? {},
                      reportType: report['report_type'] ?? 'Normal',
                      reportDate: reportDate != null
                          ? DateFormat('dd MMM yyyy').format(reportDate)
                          : '',
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
