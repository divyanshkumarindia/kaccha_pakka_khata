import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../theme.dart';
import 'accounting_template_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    // Create a fresh model instance.
    // We pass UserType.personal initially, but importState will overwrite it.
    _model = AccountingModel(userType: UserType.personal);

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
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Report',
              onPressed: () => _editReport(context),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildDetailedReportContent(context, isDark),
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountingTemplateScreen(
          templateKey: templateKey,
          initialState: stateForEdit,
          reportId: widget.reportId,
        ),
      ),
    );
  }

  // --- UI Builders (Adapted from AccountingForm) ---

  Widget _buildDetailedReportContent(BuildContext context, bool isDark) {
    // Basic logic reuse
    final currencySymbol = _getCurrencySymbol(_model.currency);

    // Calculate totals (logic from AccountingForm _showDetailedReport)
    double totalReceiptsCash = _model.openingCash;
    double totalReceiptsBank = _model.openingBank + _model.openingOther;
    double totalPaymentsCash = 0.0;
    double totalPaymentsBank = 0.0;

    // --- Accurate Data Integration (New Calculation Logic - Fixed for Custom Balances) ---
    double openingTotal =
        _model.openingCash + _model.openingBank + _model.openingOther;
    // Add custom balances to opening total
    _model.customOpeningBalances.forEach((_, value) => openingTotal += value);
    double dailyIncome = 0.0;
    double dailyExpenses = 0.0;

    // We reuse the existing loop values but separate "Daily" from "Opening"
    _model.receiptAccounts.forEach((key, entries) {
      for (var entry in entries) {
        for (var row in entry.rows) {
          totalReceiptsCash += row.cash;
          totalReceiptsBank += row.bank;
          dailyIncome += row.cash + row.bank;
        }
      }
    });

    _model.paymentAccounts.forEach((key, entries) {
      for (var entry in entries) {
        for (var row in entry.rows) {
          totalPaymentsCash += row.cash;
          totalPaymentsBank += row.bank;
          dailyExpenses += row.cash + row.bank;
        }
      }
    });

    final netSurplus = dailyIncome - dailyExpenses;
    final closingCash = totalReceiptsCash - totalPaymentsCash;
    final closingBank = totalReceiptsBank - totalPaymentsBank;
    final closingTotal = openingTotal + netSurplus;

    // --- LOAN LIABILITY TRACKING ---
    double totalLoansReceived = 0.0;
    double totalLoanRepayments = 0.0;

    // Calculate loans received from receipt accounts
    _model.receiptAccounts.forEach((key, entries) {
      if (key.toLowerCase().contains('loan')) {
        for (var entry in entries) {
          for (var row in entry.rows) {
            totalLoansReceived += row.cash + row.bank;
          }
        }
      }
    });

    // Calculate loan repayments from payment accounts
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            _model.firmName.isNotEmpty ? _model.firmName : 'Financial Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _getReportPeriodText(_model),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Receipts Section
          _buildDetailedSectionHeader(
              'Receipts', AppTheme.receiptColor, currencySymbol, isDark),
          _buildDetailedRow('Opening Balances', _model.openingCash,
              _model.openingBank + _model.openingOther, isDark,
              isBold: true),

          // Custom Opening Balances (Added Fix)
          ..._model.customOpeningBalances.entries.map((entry) {
            final title =
                _model.balanceCardTitles[entry.key] ?? 'Custom Balance';
            return _buildDetailedRow(title, entry.value, 0.0, isDark,
                isBold: false);
          }),

          const Divider(),
          ..._model.receiptAccounts.entries.map((entry) {
            double cash = 0;
            double bank = 0;
            for (var e in entry.value) {
              for (var r in e.rows) {
                cash += r.cash;
                bank += r.bank;
              }
            }
            if (cash + bank > 0) {
              return _buildDetailedRow(
                _model.receiptLabels[entry.key] ?? entry.key,
                cash,
                bank,
                isDark,
              );
            }
            return const SizedBox.shrink();
          }),
          const Divider(thickness: 2),
          _buildDetailedRow(
              'Total Receipts', totalReceiptsCash, totalReceiptsBank, isDark,
              isBold: true, color: AppTheme.receiptColor),

          const SizedBox(height: 32),

          // Payments Section
          _buildDetailedSectionHeader(
              'Payments', AppTheme.paymentColor, currencySymbol, isDark),
          ..._model.paymentAccounts.entries.map((entry) {
            double cash = 0;
            double bank = 0;
            for (var e in entry.value) {
              for (var r in e.rows) {
                cash += r.cash;
                bank += r.bank;
              }
            }
            if (cash + bank > 0) {
              return _buildDetailedRow(
                _model.paymentLabels[entry.key] ?? entry.key,
                cash,
                bank,
                isDark,
              );
            }
            return const SizedBox.shrink();
          }),
          const Divider(),
          _buildDetailedRow(
              'Closing Balance C/F', closingCash, closingBank, isDark,
              isBold: true),
          const Divider(thickness: 2),
          _buildDetailedRow(
              'Total Payments', totalPaymentsCash, totalPaymentsBank, isDark,
              isBold: true, color: AppTheme.paymentColor),

          const SizedBox(height: 32),

          // --- DAILY SUMMARY SECTION (Accurate Data Binding) ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniSummaryCard(
                        'Total Income',
                        dailyIncome,
                        const Color(0xFF10B981),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMiniSummaryCard(
                        'Total Expenses',
                        dailyExpenses,
                        const Color(0xFFEF4444),
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildMainSurplusCard(
                  netSurplus,
                  isDark,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildFooterSummaryCard(
                        'Total Balance (B/F)',
                        openingTotal,
                        'Today\'s Opening Balance',
                        const Color(0xFF6366F1),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFooterSummaryCard(
                        'Closing Balance (C/F)',
                        closingTotal,
                        'Tomorrow\'s Opening Balance',
                        const Color(0xFF3B82F6),
                        isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Builders (Summary Section Refined for Compaction) ---

  Widget _buildMiniSummaryCard(
      String label, double amount, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              '${_getCurrencySymbol(_model.currency)}${_formatAmount(amount)}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSurplusCard(double amount, bool isDark) {
    final color =
        amount >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            amount >= 0 ? 'Net Surplus' : 'Net Deficit',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_getCurrencySymbol(_model.currency)}${_formatAmount(amount)}',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSummaryCard(
      String label, double amount, String subLabel, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              '${_getCurrencySymbol(_model.currency)}${_formatAmount(amount)}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildDetailedSectionHeader(
      String title, Color color, String currencySymbol, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$title ($currencySymbol)',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        const Row(children: [
          Text('Cash', style: TextStyle(color: Colors.white, fontSize: 12)),
          SizedBox(width: 48),
          Text('Bank', style: TextStyle(color: Colors.white, fontSize: 12)),
        ])
      ]),
    );
  }

  Widget _buildDetailedRow(String label, double cash, double bank, bool isDark,
      {bool isBold = false, Color? color}) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: color ?? (isDark ? Colors.white : Colors.black87),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          SizedBox(
            width: 70,
            child: Text(_formatAmount(cash),
                style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 70,
            child: Text(_formatAmount(bank),
                style: style, textAlign: TextAlign.right),
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

  String _getReportPeriodText(AccountingModel model) {
    if (model.duration == DurationType.Daily) {
      return 'Date: ${model.periodDate}';
    } else {
      return 'Period: ${model.periodStartDate} - ${model.periodEndDate}';
    }
  }
}
