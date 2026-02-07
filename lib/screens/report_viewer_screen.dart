import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../theme.dart';
import 'accounting_template_screen.dart';
import '../services/report_service.dart';
import '../utils/report_generator.dart';

class ReportViewerScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final String reportType;
  final String reportDate;
  final String? reportId; // Added for editing support

  const ReportViewerScreen({
    Key? key,
    required this.reportData,
    required this.reportType,
    required this.reportDate,
    this.reportId,
  }) : super(key: key);

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  late AccountingModel _model;
  bool _isLoading = true;
  final ReportService _reportService = ReportService();
  bool _reportJustSaved = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    // Create a fresh model instance.
    // We pass UserType.personal initially, but importState will overwrite it.
    // Disable auto-loading from storage to prevent overwriting report data.
    _model = AccountingModel(
      userType: UserType.personal,
      shouldLoadFromStorage: false,
    );

    _model.importState(widget.reportData);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider<AccountingModel>.value(
      value: _model,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: Column(
            children: [
              const Text(
                'Report Viewer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.reportDate,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Edit Button at the Top
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _editReport(context),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('Edit Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                              : const Color(0xFFEFF6FF),
                          foregroundColor: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.5)
                                  : const Color(0xFFBFDBFE),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Action Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildPremiumActionButton(
                                  'Download Excel',
                                  Icons.file_download,
                                  AppTheme.receiptColor,
                                  () {
                                    ReportGenerator.generateAndShareExcel(
                                        context, _model);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildPremiumActionButton(
                                  'Download PDF',
                                  Icons.picture_as_pdf,
                                  AppTheme.paymentColor,
                                  () {
                                    ReportGenerator.generateAndSharePdf(
                                        context, _model);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildPremiumActionButton(
                                  'Print Report',
                                  Icons.print,
                                  const Color(0xFF6366F1), // Indigo color
                                  () {
                                    ReportGenerator.printReport(
                                        context, _model);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Save Report Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                _saveReportToSupabase(context, _model);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _reportJustSaved
                                    ? const Color(0xFF059669) // Darker green
                                    : const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _reportJustSaved
                                        ? Icons.check_circle
                                        : Icons.save,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _reportJustSaved ? 'Saved!' : 'Save Report',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailedReportContent(context, isDark),
                  ],
                ),
              ),
      ),
    );
  }

  void _editReport(BuildContext context) async {
    // Export current state to pass to editor
    final stateForEdit = _model.exportState();

    // Determine the user type to select appropriate template key
    String templateKey = 'family'; // Default
    if (_model.userType == UserType.business) templateKey = 'business';
    if (_model.userType == UserType.institute) templateKey = 'institute';
    if (_model.userType == UserType.other) templateKey = 'other';

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountingTemplateScreen(
          templateKey: templateKey,
          initialState: stateForEdit,
          reportId: widget.reportId,
        ),
      ),
    );

    // If report was saved, update the view immediately
    if (result != null && result is Map<String, dynamic> && mounted) {
      setState(() {
        // Re-import state to refresh UI
        // We can use the existing model or re-initialize logic
        _model.importState(result);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report view updated'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // --- UI Builders (Matched from AccountingForm) ---

  Widget _buildDetailedReportContent(BuildContext context, bool isDark) {
    final currencySymbol = _getCurrencySymbol(_model.currency);

    // Calculate totals
    double totalReceiptsCash = _model.openingCash;
    double totalReceiptsBank = _model.openingBank + _model.openingOther;
    double totalPaymentsCash = 0.0;
    double totalPaymentsBank = 0.0;

    // Calculate receipts (using same logic as AccountingForm)
    _model.receiptAccounts.forEach((key, entries) {
      for (var entry in entries) {
        for (var row in entry.rows) {
          totalReceiptsCash += row.cash;
          totalReceiptsBank += row.bank;
        }
      }
    });

    // Calculate payments
    _model.paymentAccounts.forEach((key, entries) {
      for (var entry in entries) {
        for (var row in entry.rows) {
          totalPaymentsCash += row.cash;
          totalPaymentsBank += row.bank;
        }
      }
    });

    final closingCash = totalReceiptsCash - totalPaymentsCash;
    final closingBank = totalReceiptsBank - totalPaymentsBank;
    final totalClosing = closingCash + closingBank;

    // --- LOAN LIABILITY TRACKING ---
    double totalLoansReceived = 0.0;
    double totalLoanRepayments = 0.0;

    _model.receiptAccounts.forEach((key, entries) {
      if (key.toLowerCase().contains('loan')) {
        for (var entry in entries) {
          for (var row in entry.rows) {
            totalLoansReceived += row.cash + row.bank;
          }
        }
      }
    });

    _model.paymentAccounts.forEach((key, entries) {
      if (key.toLowerCase().contains('loan')) {
        for (var entry in entries) {
          for (var row in entry.rows) {
            totalLoanRepayments += row.cash + row.bank;
          }
        }
      }
    });

    final netLoanLiability = totalLoansReceived - totalLoanRepayments;
    final hasLoanTransactions =
        totalLoansReceived > 0 || totalLoanRepayments > 0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        children: [
          // Firm Name and Period Header
          Text(
            _model.firmName.isNotEmpty && !_model.isDefaultFirmName
                ? _model.firmName
                : _model.t('card_${_model.userType.name}'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Balance Report',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _getReportPeriodText(),
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _getReportTimestamp(),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '(All amounts in ${_getCurrencyName(_model.currency)})',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Receipts Table
          _buildDetailedTable(
            '${_model.userType == UserType.personal ? _model.t('label_income') : _model.t('label_receipts')} ($currencySymbol)',
            AppTheme.receiptColor,
            isDark ? const Color(0xFF111827) : const Color(0xFFF0FDF4),
            [
              // Table Header
              _buildTableRow(
                [
                  'Particulars',
                  'Cash ($currencySymbol)',
                  'Bank ($currencySymbol)',
                  'Total ($currencySymbol)'
                ],
                isDark,
                isHeader: true,
              ),
              // Opening Balance
              _buildTableRow(
                ['Opening Balances B/F', '', '', ''],
                isDark,
                isBold: true,
              ),
              // Cash Balance B/F - Always show
              _buildTableRow(
                [
                  '   ${_model.getBalanceCardTitle('cash', defaultValue: _model.getDefaultBalanceTitle('cash'))}',
                  _formatAmount(_model.openingCash),
                  '0.00',
                  _formatAmount(_model.openingCash)
                ],
                isDark,
              ),
              // Bank Balance B/F - Always show
              _buildTableRow(
                [
                  '   ${_model.getBalanceCardTitle('bank', defaultValue: _model.getDefaultBalanceTitle('bank'))}',
                  '0.00',
                  _formatAmount(_model.openingBank),
                  _formatAmount(_model.openingBank)
                ],
                isDark,
              ),
              // Other Balance B/F - Always show
              _buildTableRow(
                [
                  '   ${_model.getBalanceCardTitle('other', defaultValue: _model.getDefaultBalanceTitle('other'))}',
                  '0.00',
                  _formatAmount(_model.openingOther),
                  _formatAmount(_model.openingOther)
                ],
                isDark,
              ),
              // Custom Balance Boxes (show only if > 0)
              ..._model.customOpeningBalances.entries
                  .where((e) => e.value > 0)
                  .map((entry) {
                final title = _model.getBalanceCardTitle(entry.key,
                    defaultValue: 'Custom Balance');
                return _buildTableRow(
                  [
                    '   $title',
                    '0.00',
                    _formatAmount(entry.value),
                    _formatAmount(entry.value)
                  ],
                  isDark,
                );
              }),
              // Income Categories (Detailed)
              ..._model.receiptAccounts.entries.expand((entry) {
                // Check if this category has any non-zero transactions
                bool hasData = entry.value
                    .any((e) => e.rows.any((r) => r.cash > 0 || r.bank > 0));

                if (!hasData) return <Widget>[];

                List<Widget> groupRows = [];

                // 1. Category Header (Bold, like Opening Balances info)
                groupRows.add(_buildTableRow(
                  [
                    _model.receiptLabels[entry.key] ?? entry.key,
                    '',
                    '',
                    ''
                  ], // Amounts empty for header
                  isDark,
                  isBold: true,
                ));

                // 2. Individual Transactions (Indented)
                for (var e in entry.value) {
                  for (var row in e.rows) {
                    if (row.cash > 0 || row.bank > 0) {
                      String label = row.particulars.isNotEmpty
                          ? row.particulars
                          : (e.description.isNotEmpty
                              ? e.description
                              : 'Entry');
                      groupRows.add(_buildTableRow(
                        [
                          '   $label', // Indent
                          _formatAmount(row.cash),
                          _formatAmount(row.bank),
                          _formatAmount(row.cash + row.bank)
                        ],
                        isDark,
                      ));
                    }
                  }
                }
                return groupRows;
              }).toList(),
              // Divider
              Divider(
                  height: 1,
                  thickness: 2,
                  color: isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFF10B981)),
              // Total Receipts
              _buildTableRow(
                [
                  _model.userType == UserType.personal
                      ? _model.t('label_total_income')
                      : _model.t('label_total_receipts'),
                  _formatAmount(totalReceiptsCash),
                  _formatAmount(totalReceiptsBank),
                  _formatAmount(totalReceiptsCash + totalReceiptsBank)
                ],
                isDark,
                isBold: true,
                color: AppTheme.receiptColor,
              ),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Payments Table
          _buildDetailedTable(
            '${_model.userType == UserType.personal ? _model.t('label_expenses') : _model.t('label_payments')} ($currencySymbol)',
            AppTheme.paymentColor,
            isDark ? const Color(0xFF111827) : const Color(0xFFFEF2F2),
            [
              // Table Header
              _buildTableRow(
                [
                  'Particulars',
                  'Cash ($currencySymbol)',
                  'Bank ($currencySymbol)',
                  'Total ($currencySymbol)'
                ],
                isDark,
                isHeader: true,
              ),
              // Expense Categories (Detailed)
              ..._model.paymentAccounts.entries.expand((entry) {
                // Check if this category has any non-zero transactions
                bool hasData = entry.value
                    .any((e) => e.rows.any((r) => r.cash > 0 || r.bank > 0));

                if (!hasData) return <Widget>[];

                List<Widget> groupRows = [];

                // 1. Category Header (Bold)
                groupRows.add(_buildTableRow(
                  [
                    _model.paymentLabels[entry.key] ?? entry.key,
                    '',
                    '',
                    ''
                  ], // Amounts empty for header
                  isDark,
                  isBold: true,
                ));

                // 2. Individual Transactions (Indented)
                for (var e in entry.value) {
                  for (var row in e.rows) {
                    if (row.cash > 0 || row.bank > 0) {
                      String label = row.particulars.isNotEmpty
                          ? row.particulars
                          : (e.description.isNotEmpty
                              ? e.description
                              : 'Entry');
                      groupRows.add(_buildTableRow(
                        [
                          '   $label', // Indent
                          _formatAmount(row.cash),
                          _formatAmount(row.bank),
                          _formatAmount(row.cash + row.bank)
                        ],
                        isDark,
                      ));
                    }
                  }
                }
                return groupRows;
              }).toList(),
              // Closing Balance C/F
              _buildTableRow(
                [
                  'Closing Balance C/F',
                  _formatAmount(closingCash),
                  _formatAmount(closingBank),
                  _formatAmount(totalClosing)
                ],
                isDark,
                isBold: true,
              ),
              // Divider
              Divider(
                  height: 1,
                  thickness: 2,
                  color:
                      isDark ? const Color(0xFF4B5563) : AppTheme.paymentColor),
              // Total Payments
              _buildTableRow(
                [
                  _model.userType == UserType.personal
                      ? _model.t('label_total_expenses')
                      : _model.t('label_total_payments'),
                  _formatAmount(totalPaymentsCash + closingCash),
                  _formatAmount(totalPaymentsBank + closingBank),
                  _formatAmount(
                      totalPaymentsCash + totalPaymentsBank + totalClosing)
                ],
                isDark,
                isBold: true,
                color: AppTheme.paymentColor,
              ),
            ],
            isDark,
          ),

          const SizedBox(height: 24),

          // Closing Balance Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Closing Balance Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Closing Cash',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$currencySymbol${_formatAmount(closingCash)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: closingCash >= 0
                                  ? AppTheme.receiptColor
                                  : AppTheme.paymentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Closing Bank',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$currencySymbol${_formatAmount(closingBank)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: closingBank >= 0
                                  ? AppTheme.receiptColor
                                  : AppTheme.paymentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Total Closing',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$currencySymbol${_formatAmount(totalClosing)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- LOAN LIABILITIES SECTION ---
          if (hasLoanTransactions) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Total Loan Liabilities',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Loans Summary Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward,
                                    color: const Color(0xFFEF4444), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Loans Received',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$currencySymbol${_formatAmount(totalLoansReceived)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: isDark
                            ? const Color(0xFF374151)
                            : const Color(0xFFE5E7EB),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward,
                                    color: const Color(0xFF10B981), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Loan Repayments',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$currencySymbol${_formatAmount(totalLoanRepayments)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Net Outstanding Liability
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: netLoanLiability > 0
                            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                            : [
                                const Color(0xFF10B981),
                                const Color(0xFF059669)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          netLoanLiability > 0
                              ? 'Net Outstanding Liability'
                              : 'Loans Fully Repaid',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              netLoanLiability > 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$currencySymbol${_formatAmount(netLoanLiability.abs())}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (netLoanLiability > 0) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Amount pending to be repaid',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper: Build detailed table
  Widget _buildDetailedTable(String title, Color headerColor, Color bgColor,
      List<Widget> rows, bool isDark) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: headerColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Table Content
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(
              color: isDark
                  ? const Color(0xFF374151)
                  : headerColor.withValues(alpha: 0.3),
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Column(
            children: rows,
          ),
        ),
      ],
    );
  }

  // Helper: Build table row for detailed report
  Widget _buildTableRow(List<String> cells, bool isDark,
      {bool isHeader = false, bool isBold = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Particulars (40%)
          Expanded(
            flex: 40,
            child: Text(
              cells[0],
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight:
                    isHeader || isBold ? FontWeight.bold : FontWeight.normal,
                color: color ??
                    (isDark
                        ? (isHeader ? Colors.grey[300] : Colors.grey[300])
                        : (isHeader ? Colors.black87 : Colors.black87)),
              ),
            ),
          ),
          // Cash (20%)
          Expanded(
            flex: 20,
            child: Text(
              cells[1],
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight:
                    isHeader || isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Bank (20%)
          Expanded(
            flex: 20,
            child: Text(
              cells[2],
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight:
                    isHeader || isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Total (20%)
          Expanded(
            flex: 20,
            child: Text(
              cells[3],
              style: TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight:
                    isHeader || isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount == 0.0) return '0.00';
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    String formatted = amount.toStringAsFixed(2);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }

  String _getCurrencySymbol(String currency) {
    // Simple lookup, fast enough for now
    if (currency == 'USD') return '\$';
    if (currency == 'EUR') return '€';
    if (currency == 'GBP') return '£';
    return '₹';
  }

  String _getCurrencyName(String currencyCode) {
    // Simple lookup
    if (currencyCode == 'INR') return 'Indian Rupee';
    if (currencyCode == 'USD') return 'US Dollar';
    if (currencyCode == 'EUR') return 'Euro';
    if (currencyCode == 'GBP') return 'British Pound';
    return currencyCode;
  }

  String _getReportTimestamp() {
    // If we have a saved snapshot timestamp, show that
    if (widget.reportData.containsKey('saved_at')) {
      final savedAt = DateTime.tryParse(widget.reportData['saved_at']);
      if (savedAt != null) {
        // Format: "Report as of 25 Jan 2025 09:30 PM"
        final date =
            '${savedAt.day} ${_getMonthName(savedAt.month)} ${savedAt.year}';
        final time = MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(savedAt),
          alwaysUse24HourFormat: false,
        );
        return 'Snapshot as of $date, $time';
      }
    }

    // Fallback to period logic
    if (_model.duration == DurationType.Daily) {
      return 'Daily Report - ${_model.periodDate.isEmpty ? "No date selected" : _model.periodDate}';
    } else {
      return 'Report - ${_model.periodStartDate} to ${_model.periodEndDate}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  // Helper: Build premium action button
  Widget _buildPremiumActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Save Report to Supabase
  Future<void> _saveReportToSupabase(
      BuildContext context, AccountingModel model) async {
    try {
      // Export current state
      final reportData = model.exportState();

      // Add saved_at timestamp
      reportData['saved_at'] = DateTime.now().toIso8601String();

      // Determine report type
      String reportType = 'Detailed';

      // Get use case type (capitalize first letter to match DB constraint)
      String useCaseType = model.userType.name[0].toUpperCase() +
          model.userType.name.substring(1);

      await _reportService.saveReport(
        reportType,
        reportData,
        useCaseType: useCaseType,
      );

      // Update state to show checkmark
      if (mounted) {
        setState(() {
          _reportJustSaved = true;
        });

        // Reset after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _reportJustSaved = false;
            });
          }
        });
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Report saved successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to save report: $e')),
              ],
            ),
            backgroundColor: AppTheme.paymentColor,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // Helper: Get report period text (Matched from AccountingForm)
  String _getReportPeriodText() {
    switch (_model.duration) {
      case DurationType.Daily:
        return 'Daily Report - ${_model.periodDate.isEmpty ? "No date selected" : _model.periodDate}';
      case DurationType.Weekly:
        if (_model.periodStartDate.isEmpty || _model.periodEndDate.isEmpty) {
          return 'Weekly Report - No period selected';
        }
        return 'Weekly Report - ${_model.periodStartDate} to ${_model.periodEndDate}';
      case DurationType.Monthly:
        return 'Monthly Report - ${_model.periodDate.isEmpty ? "No month selected" : _model.periodDate}';
      case DurationType.Yearly:
        if (_model.periodStartDate.isEmpty || _model.periodEndDate.isEmpty) {
          // Fallback for old yearly reports with single date
          return 'Yearly Report - ${_model.periodDate.isEmpty ? "No year selected" : _model.periodDate}';
        }
        return 'Yearly Report - ${_model.periodStartDate} to ${_model.periodEndDate}';
      default:
        return 'Report';
    }
  }
}
