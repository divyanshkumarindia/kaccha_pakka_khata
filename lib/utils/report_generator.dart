import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../state/accounting_model.dart';
import 'package:intl/intl.dart';

/// Utility class for generating reports in various formats
class ReportGenerator {
  /// Generate and share/download PDF report
  static Future<void> generateAndSharePdf(
      BuildContext context, AccountingModel model) async {
    try {
      // Show loading indicator
      _showLoadingDialog(context, 'Generating PDF...');

      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy').format(now);

      // Get data from model
      final firmName = model.firmName;
      final currency = model.currency;
      final totalReceipts = model.receiptsTotal;
      final totalPayments = model.paymentsTotal;
      final netBalance = model.netBalance;
      final openingBalance =
          model.openingCash + model.openingBank + model.openingOther;
      final closingBalance = openingBalance + netBalance;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green700,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    firmName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Financial Report - $dateStr',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Opening Balances Section
            _buildPdfSection('Opening Balances', [
              _buildPdfRow('Cash (B/F)', model.openingCash, currency),
              _buildPdfRow('Bank (B/F)', model.openingBank, currency),
              _buildPdfRow('Other (B/F)', model.openingOther, currency),
              pw.Divider(),
              _buildPdfRow('Total Opening', openingBalance, currency,
                  isBold: true),
            ]),
            pw.SizedBox(height: 16),

            // Receipts Section
            _buildPdfSection('Receipts (Income)', [
              ...model.receiptAccounts.entries.map((entry) {
                final total = _calculateEntryTotal(entry.value);
                return _buildPdfRow(model.receiptLabels[entry.key] ?? entry.key,
                    total, currency);
              }),
              pw.Divider(),
              _buildPdfRow('Total Receipts', totalReceipts, currency,
                  isBold: true, color: PdfColors.green700),
            ]),
            pw.SizedBox(height: 16),

            // Payments Section
            _buildPdfSection('Payments (Expenses)', [
              ...model.paymentAccounts.entries.map((entry) {
                final total = _calculateEntryTotal(entry.value);
                return _buildPdfRow(model.paymentLabels[entry.key] ?? entry.key,
                    total, currency);
              }),
              pw.Divider(),
              _buildPdfRow('Total Payments', totalPayments, currency,
                  isBold: true, color: PdfColors.red700),
            ]),
            pw.SizedBox(height: 20),

            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  _buildPdfRow('Total Receipts', totalReceipts, currency,
                      color: PdfColors.green700),
                  _buildPdfRow('Total Payments', totalPayments, currency,
                      color: PdfColors.red700),
                  pw.Divider(),
                  _buildPdfRow(
                    netBalance >= 0 ? 'Net Surplus' : 'Net Deficit',
                    netBalance.abs(),
                    currency,
                    isBold: true,
                    color:
                        netBalance >= 0 ? PdfColors.green700 : PdfColors.red700,
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfRow(
                      'Closing Balance (C/F)', closingBalance, currency,
                      isBold: true),
                ],
              ),
            ),

            // Footer
            pw.SizedBox(height: 30),
            pw.Center(
              child: pw.Text(
                'Generated by Kaacha Pakka Khata',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Share/Save the PDF
      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate and share CSV report (Excel-compatible)
  static Future<void> generateAndShareExcel(
      BuildContext context, AccountingModel model) async {
    try {
      _showLoadingDialog(context, 'Generating Excel...');

      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy').format(now);
      final currency = model.currency;

      // Build CSV content
      final StringBuffer csv = StringBuffer();

      // Helper to add CSV row
      void addRow(List<String> cells) {
        // Escape cells that contain commas or quotes
        final escaped = cells.map((cell) {
          if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
            return '"${cell.replaceAll('"', '""')}"';
          }
          return cell;
        }).toList();
        csv.writeln(escaped.join(','));
      }

      // Title
      addRow([model.firmName]);
      addRow(['Financial Report - $dateStr']);
      addRow([]);

      // Opening Balances
      addRow(['Opening Balances']);
      addRow(['Category', 'Amount ($currency)']);
      addRow(['Cash (B/F)', model.openingCash.toStringAsFixed(2)]);
      addRow(['Bank (B/F)', model.openingBank.toStringAsFixed(2)]);
      addRow(['Other (B/F)', model.openingOther.toStringAsFixed(2)]);
      final openingBalance =
          model.openingCash + model.openingBank + model.openingOther;
      addRow(['Total Opening', openingBalance.toStringAsFixed(2)]);
      addRow([]);

      // Receipts
      addRow(['Receipts (Income)']);
      addRow(['Category', 'Amount ($currency)']);
      for (final entry in model.receiptAccounts.entries) {
        final total = _calculateEntryTotal(entry.value);
        addRow([
          model.receiptLabels[entry.key] ?? entry.key,
          total.toStringAsFixed(2)
        ]);
      }
      addRow(['Total Receipts', model.receiptsTotal.toStringAsFixed(2)]);
      addRow([]);

      // Payments
      addRow(['Payments (Expenses)']);
      addRow(['Category', 'Amount ($currency)']);
      for (final entry in model.paymentAccounts.entries) {
        final total = _calculateEntryTotal(entry.value);
        addRow([
          model.paymentLabels[entry.key] ?? entry.key,
          total.toStringAsFixed(2)
        ]);
      }
      addRow(['Total Payments', model.paymentsTotal.toStringAsFixed(2)]);
      addRow([]);

      // Summary
      addRow(['Summary']);
      addRow(['Description', 'Amount ($currency)']);
      addRow(['Total Receipts', model.receiptsTotal.toStringAsFixed(2)]);
      addRow(['Total Payments', model.paymentsTotal.toStringAsFixed(2)]);
      final netBalance = model.netBalance;
      addRow([
        netBalance >= 0 ? 'Net Surplus' : 'Net Deficit',
        netBalance.abs().toStringAsFixed(2)
      ]);
      final closingBalance = openingBalance + netBalance;
      addRow(['Closing Balance (C/F)', closingBalance.toStringAsFixed(2)]);

      // Save file to system temp directory
      final directory = Directory.systemTemp;
      final filePath =
          '${directory.path}/report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
      final file = File(filePath);
      await file.writeAsString(csv.toString());

      if (context.mounted) Navigator.pop(context);

      // Share the file
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Financial Report - $dateStr',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.status == ShareResultStatus.success
                ? 'Report shared successfully! (Open with Excel or Google Sheets)'
                : 'Report saved! You can open it with Excel or Google Sheets.'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Print the report directly
  static Future<void> printReport(
      BuildContext context, AccountingModel model) async {
    try {
      _showLoadingDialog(context, 'Preparing to print...');

      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy').format(now);
      final currency = model.currency;
      final firmName = model.firmName;
      final totalReceipts = model.receiptsTotal;
      final totalPayments = model.paymentsTotal;
      final netBalance = model.netBalance;
      final openingBalance =
          model.openingCash + model.openingBank + model.openingOther;
      final closingBalance = openingBalance + netBalance;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    firmName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Financial Report - $dateStr',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Opening Balances
            _buildPdfSection('Opening Balances', [
              _buildPdfRow('Cash (B/F)', model.openingCash, currency),
              _buildPdfRow('Bank (B/F)', model.openingBank, currency),
              _buildPdfRow('Other (B/F)', model.openingOther, currency),
              pw.Divider(),
              _buildPdfRow('Total Opening', openingBalance, currency,
                  isBold: true),
            ]),
            pw.SizedBox(height: 16),

            // Receipts
            _buildPdfSection('Receipts', [
              ...model.receiptAccounts.entries.map((entry) {
                final total = _calculateEntryTotal(entry.value);
                return _buildPdfRow(model.receiptLabels[entry.key] ?? entry.key,
                    total, currency);
              }),
              pw.Divider(),
              _buildPdfRow('Total Receipts', totalReceipts, currency,
                  isBold: true),
            ]),
            pw.SizedBox(height: 16),

            // Payments
            _buildPdfSection('Payments', [
              ...model.paymentAccounts.entries.map((entry) {
                final total = _calculateEntryTotal(entry.value);
                return _buildPdfRow(model.paymentLabels[entry.key] ?? entry.key,
                    total, currency);
              }),
              pw.Divider(),
              _buildPdfRow('Total Payments', totalPayments, currency,
                  isBold: true),
            ]),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  _buildPdfRow('Total Receipts', totalReceipts, currency),
                  _buildPdfRow('Total Payments', totalPayments, currency),
                  pw.Divider(),
                  _buildPdfRow(
                    netBalance >= 0 ? 'Net Surplus' : 'Net Deficit',
                    netBalance.abs(),
                    currency,
                    isBold: true,
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfRow(
                      'Closing Balance (C/F)', closingBalance, currency,
                      isBold: true),
                ],
              ),
            ),
          ],
        ),
      );

      if (context.mounted) Navigator.pop(context);

      // Open print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Financial Report - $dateStr',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper to calculate total from TransactionEntry list
  static double _calculateEntryTotal(dynamic entries) {
    if (entries is! List) return 0.0;
    double total = 0.0;
    for (final entry in entries) {
      if (entry.rows != null) {
        for (final row in entry.rows) {
          total += (row.cash ?? 0.0) + (row.bank ?? 0.0);
        }
      }
    }
    return total;
  }

  // Helper methods
  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(children: children),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfRow(String label, double amount, String currency,
      {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
          pw.Text(
            _formatCurrency(amount, currency),
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCurrency(double amount, String currency) {
    final symbol = _getCurrencySymbol(currency);
    return '$symbol ${amount.toStringAsFixed(2)}';
  }

  static String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency;
    }
  }
}
