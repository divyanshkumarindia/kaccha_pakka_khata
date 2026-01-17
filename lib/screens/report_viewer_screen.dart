import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../theme.dart';

class ReportViewerScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final String reportType;
  final String reportDate;

  const ReportViewerScreen({
    Key? key,
    required this.reportData,
    required this.reportType,
    required this.reportDate,
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

    await _model.importState(widget.reportData);

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
              Text(
                widget.reportType == 'Detailed' ? 'Detailed Report' : 'Report',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                child: widget.reportType == 'Detailed'
                    ? _buildDetailedReportContent(context, isDark)
                    : _buildBasicReportContent(context, isDark),
              ),
      ),
    );
  }

  // --- UI Builders (Adapted from AccountingForm) ---

  Widget _buildBasicReportContent(BuildContext context, bool isDark) {
    final currencySymbol = _getCurrencySymbol(_model.currency);
    final closingBalance = _model.netBalance;
    final netReceipts = _model.receiptsTotal;
    final netPayments = _model.paymentsTotal;

    return Container(
      constraints: const BoxConstraints(maxWidth: 850),
      child: Column(
        children: [
          // Report Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _model.firmName.isNotEmpty
                      ? _model.firmName
                      : 'Financial Report',
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
                ),
                const SizedBox(height: 24),

                // Net Receipts & Payments Rows
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryBox(
                        'Net Receipts',
                        netReceipts,
                        AppTheme.receiptColor,
                        const Color(0xFFECFDF5),
                        currencySymbol,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryBox(
                        'Net Payments',
                        netPayments,
                        AppTheme.paymentColor,
                        const Color(0xFFFEF2F2),
                        currencySymbol,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Closing Balance
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Closing Balance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      Text(
                        '$currencySymbol${_formatAmount(closingBalance)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedReportContent(BuildContext context, bool isDark) {
    // Basic logic reuse
    final currencySymbol = _getCurrencySymbol(_model.currency);

    // Calculate totals (logic from AccountingForm _showDetailedReport)
    double totalReceiptsCash = _model.openingCash;
    double totalReceiptsBank = _model.openingBank + _model.openingOther;
    double totalPaymentsCash = 0.0;
    double totalPaymentsBank = 0.0;

    _model.receiptAccounts.forEach((key, entries) {
      for (var entry in entries) {
        for (var row in entry.rows) {
          totalReceiptsCash += row.cash;
          totalReceiptsBank += row.bank;
        }
      }
    });

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
    // final totalClosing = closingCash + closingBank; // Unused variable warning fix

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
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildSummaryBox(String title, double amount, Color textColor,
      Color bgColor, String currencySymbol) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor, width: 1.5),
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13, color: textColor, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            '$currencySymbol${_formatAmount(amount)}',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

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
