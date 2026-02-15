import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import 'package:intl/intl.dart';

/// Utility class for generating reports in various formats
class ReportGenerator {
  /// Generate and share/download PDF report
  static Future<void> generateAndSharePdf(
      BuildContext context, AccountingModel model) async {
    try {
      // Show loading indicator
      _showLoadingDialog(context, 'Generating PDF...');

      final now = DateTime.now();

      // Load Fonts
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      final italicFont = await PdfGoogleFonts.robotoItalic();

      final pdf = _buildReportPdf(model, font, boldFont, italicFont);

      // Share/Save the PDF
      final bytes = await pdf.save();

      // Close loading dialog with proper context check
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
          // Dialog might already be closed
        }
      }

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
        try {
          Navigator.of(context, rootNavigator: true)
              .pop(); // Close loading dialog
        } catch (_) {
          // Dialog might already be closed
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate and share/download CSV report
  static Future<void> generateAndShareExcel(
      BuildContext context, AccountingModel model) async {
    try {
      _showLoadingDialog(context, 'Generating Excel...');

      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy').format(now);
      final currency = model.currency;

      // Calculate loan liabilities
      double totalLoansReceived = 0.0;
      double totalLoanRepayments = 0.0;

      model.receiptAccounts.forEach((key, entries) {
        if (key.toLowerCase().contains('loan')) {
          totalLoansReceived += _calculateEntryTotal(entries);
        }
      });

      model.paymentAccounts.forEach((key, entries) {
        if (key.toLowerCase().contains('loan')) {
          totalLoanRepayments += _calculateEntryTotal(entries);
        }
      });

      final netLoanLiability = totalLoansReceived - totalLoanRepayments;
      final hasLoanTransactions =
          totalLoansReceived > 0 || totalLoanRepayments > 0;

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

      // Loan Liabilities Section (if applicable)
      if (hasLoanTransactions) {
        addRow([]);
        addRow(['Loan Liabilities']);
        addRow(['Description', 'Amount ($currency)']);
        addRow(['Loans Received', totalLoansReceived.toStringAsFixed(2)]);
        addRow(['Loan Repayments', totalLoanRepayments.toStringAsFixed(2)]);
        addRow([
          netLoanLiability > 0
              ? 'Net Outstanding Liability'
              : 'Loans Fully Repaid',
          netLoanLiability.abs().toStringAsFixed(2)
        ]);
      }

      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be closed
        }
      }

      final fileName =
          'report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
      final csvString = csv.toString();

      if (kIsWeb) {
        // Direct Download for Web
        final bytes = utf8.encode(csvString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report downloaded successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        // Native Share (Mobile/Desktop)
        final box = context.findRenderObject() as RenderBox?;
        final csvData = utf8.encode(csvString);
        final xFile = XFile.fromData(
          csvData,
          mimeType: 'text/csv',
          name: fileName,
        );

        // ignore: deprecated_member_use
        final result = await Share.shareXFiles(
          [xFile],
          subject: 'Financial Report - $dateStr',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );

        if (context.mounted && result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report shared successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be closed
        }
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

      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy').format(now);

      // Load Fonts for Currency Support
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      final italicFont = await PdfGoogleFonts.robotoItalic();

      final pdf = _buildReportPdf(model, font, boldFont, italicFont);

      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be closed
        }
      }

      // Open print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Financial Report - $dateStr',
      );
    } catch (e) {
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be closed
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static pw.Document _buildReportPdf(AccountingModel model, pw.Font font,
      pw.Font boldFont, pw.Font italicFont) {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy').format(now);

    // Get data from model
    final firmName = model.firmName.isNotEmpty && !model.isDefaultFirmName
        ? model.firmName
        : model.t('card_${model.userType.name}');
    final currency = model.currency;
    final currencySymbol = _getCurrencySymbol(currency);

    // Calculate totals
    double totalReceiptsCash = model.openingCash;
    double totalReceiptsBank = model.openingBank + model.openingOther;
    double totalPaymentsCash = 0.0;
    double totalPaymentsBank = 0.0;

    // Receipts
    model.receiptAccounts.forEach((key, entries) {
      for (var entry in entries) {
        for (var row in entry.rows) {
          totalReceiptsCash += row.cash;
          totalReceiptsBank += row.bank;
        }
      }
    });

    // Payments
    model.paymentAccounts.forEach((key, entries) {
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

    // Calculate loan liabilities
    double totalLoansReceived = 0.0;
    double totalLoanRepayments = 0.0;

    model.receiptAccounts.forEach((key, entries) {
      if (key.toLowerCase().contains('loan')) {
        totalLoansReceived += _calculateEntryTotal(entries);
      }
    });

    model.paymentAccounts.forEach((key, entries) {
      if (key.toLowerCase().contains('loan')) {
        totalLoanRepayments += _calculateEntryTotal(entries);
      }
    });

    final netLoanLiability = totalLoansReceived - totalLoanRepayments;
    final hasLoanTransactions =
        totalLoansReceived > 0 || totalLoanRepayments > 0;

    // Colors
    final PdfColor receiptColor = PdfColor.fromInt(0xFF10B981); // Green
    final PdfColor paymentColor = PdfColor.fromInt(0xFFEF4444); // Red

    // Helper for formatting amounts
    String fmt(double amount) => amount.abs().toStringAsFixed(2);

    // Helper for table rows
    pw.Widget buildRow(
      List<String> cells, {
      bool isHeader = false,
      bool isBold = false,
      PdfColor? backgroundColor,
      PdfColor? textColor,
    }) {
      return pw.Container(
        color: backgroundColor,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 4,
              child: pw.Text(
                cells[0],
                style: pw.TextStyle(
                  fontWeight: isHeader || isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: textColor ?? PdfColors.black,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                cells[1],
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontWeight: isHeader || isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: textColor ?? PdfColors.black,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                cells[2],
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontWeight: isHeader || isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: textColor ?? PdfColors.black,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                cells[3],
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontWeight: isHeader || isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: textColor ?? PdfColors.black,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
          italic: italicFont,
        ),
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // --- HEADER ---
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  firmName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Balance Report',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Snapshot as of $dateStr', // Simplified period for now, or match ReportViewer logic if possible
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey600,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '(All amounts in ${_getCurrencyName(currency)})',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // --- INCOME / RECEIPTS TABLE ---
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.green50, // Very light green
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              '${model.userType == UserType.personal ? model.t('label_income') : model.t('label_receipts')} ($currencySymbol)',
              style: pw.TextStyle(
                color: receiptColor,
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Container(
            color: PdfColors.green50,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Column(
              children: [
                // Header
                buildRow(
                  [
                    'Particulars',
                    'Cash ($currencySymbol)',
                    'Bank ($currencySymbol)',
                    'Total ($currencySymbol)'
                  ],
                  isHeader: true,
                ),
                pw.SizedBox(height: 4),

                // Opening Balance Header
                buildRow(['Opening Balances B/F', '', '', ''], isBold: true),

                // Opening Balances Detail
                buildRow([
                  '   ${model.getBalanceCardTitle('cash', defaultValue: model.getDefaultBalanceTitle('cash'))}',
                  fmt(model.openingCash),
                  '0.00',
                  fmt(model.openingCash)
                ]),
                buildRow([
                  '   ${model.getBalanceCardTitle('bank', defaultValue: model.getDefaultBalanceTitle('bank'))}',
                  '0.00',
                  fmt(model.openingBank),
                  fmt(model.openingBank)
                ]),
                buildRow([
                  '   ${model.getBalanceCardTitle('other', defaultValue: model.getDefaultBalanceTitle('other'))}',
                  '0.00',
                  fmt(model.openingOther),
                  fmt(model.openingOther)
                ]),

                // Custom Opening Balances
                ...model.customOpeningBalances.entries
                    .where((e) => e.value > 0)
                    .map((entry) {
                  final title = model.getBalanceCardTitle(entry.key,
                      defaultValue: 'Custom Balance');
                  return buildRow([
                    '   $title',
                    '0.00',
                    fmt(entry.value),
                    fmt(entry.value)
                  ]);
                }),

                // Detailed Receipts
                ...model.receiptAccounts.entries.expand((entry) {
                  bool hasData = entry.value
                      .any((e) => e.rows.any((r) => r.cash > 0 || r.bank > 0));
                  if (!hasData) return <pw.Widget>[];

                  List<pw.Widget> rows = [];
                  // Category Header
                  rows.add(buildRow(
                      [model.receiptLabels[entry.key] ?? entry.key, '', '', ''],
                      isBold: true));

                  // Entries
                  for (var e in entry.value) {
                    for (var row in e.rows) {
                      double rowCash = row.cash;
                      double rowBank = row.bank;
                      if (rowCash > 0 || rowBank > 0) {
                        String label = row.particulars.isNotEmpty
                            ? row.particulars
                            : (e.description.isNotEmpty
                                ? e.description
                                : 'Entry');
                        rows.add(buildRow([
                          '   $label',
                          fmt(rowCash),
                          fmt(rowBank),
                          fmt(rowCash + rowBank)
                        ]));
                      }
                    }
                  }
                  return rows;
                }),

                pw.Divider(color: receiptColor),
                // Total Receipts
                buildRow(
                  [
                    model.userType == UserType.personal
                        ? model.t('label_total_income')
                        : model.t('label_total_receipts'),
                    fmt(totalReceiptsCash),
                    fmt(totalReceiptsBank),
                    fmt(totalReceiptsCash + totalReceiptsBank),
                  ],
                  isBold: true,
                  textColor: receiptColor,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // --- EXPENSES / PAYMENTS TABLE ---
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.red50, // Very light red
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              '${model.userType == UserType.personal ? model.t('label_expenses') : model.t('label_payments')} ($currencySymbol)',
              style: pw.TextStyle(
                color: paymentColor,
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Container(
            color: PdfColors.red50,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Column(
              children: [
                // Header
                buildRow(
                  [
                    'Particulars',
                    'Cash ($currencySymbol)',
                    'Bank ($currencySymbol)',
                    'Total ($currencySymbol)'
                  ],
                  isHeader: true,
                ),
                pw.SizedBox(height: 4),

                // Detailed Payments
                ...model.paymentAccounts.entries.expand((entry) {
                  bool hasData = entry.value
                      .any((e) => e.rows.any((r) => r.cash > 0 || r.bank > 0));
                  if (!hasData) return <pw.Widget>[];

                  List<pw.Widget> rows = [];
                  // Category Header
                  rows.add(buildRow(
                      [model.paymentLabels[entry.key] ?? entry.key, '', '', ''],
                      isBold: true));

                  // Entries
                  for (var e in entry.value) {
                    for (var row in e.rows) {
                      double rowCash = row.cash;
                      double rowBank = row.bank;
                      if (rowCash > 0 || rowBank > 0) {
                        String label = row.particulars.isNotEmpty
                            ? row.particulars
                            : (e.description.isNotEmpty
                                ? e.description
                                : 'Entry');
                        rows.add(buildRow([
                          '   $label',
                          fmt(rowCash),
                          fmt(rowBank),
                          fmt(rowCash + rowBank)
                        ]));
                      }
                    }
                  }
                  return rows;
                }),

                // Closing Balance C/F
                buildRow(
                  [
                    'Closing Balance C/F',
                    fmt(closingCash),
                    fmt(closingBank),
                    fmt(totalClosing),
                  ],
                  isBold: true,
                ),

                pw.Divider(color: paymentColor),
                // Total Payments
                buildRow(
                  [
                    model.userType == UserType.personal
                        ? model.t('label_total_expenses')
                        : model.t('label_total_payments'),
                    fmt(totalPaymentsCash + closingCash),
                    fmt(totalPaymentsBank + closingBank),
                    fmt(totalPaymentsCash + totalPaymentsBank + totalClosing),
                  ],
                  isBold: true,
                  textColor: paymentColor,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // --- CLOSING BALANCE SUMMARY ---
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'Closing Balance Summary',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
                pw.SizedBox(height: 12),
                pw.Row(children: [
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('Closing Cash',
                            style: const pw.TextStyle(
                                color: PdfColors.grey600, fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('$currencySymbol${fmt(closingCash)}',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: closingCash >= 0
                                    ? receiptColor
                                    : paymentColor,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  pw.Container(width: 1, height: 30, color: PdfColors.grey300),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('Closing Bank',
                            style: const pw.TextStyle(
                                color: PdfColors.grey600, fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('$currencySymbol${fmt(closingBank)}',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: closingBank >= 0
                                    ? receiptColor
                                    : paymentColor,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  pw.Container(width: 1, height: 30, color: PdfColors.grey300),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('Total Closing',
                            style: const pw.TextStyle(
                                color: PdfColors.grey600, fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('$currencySymbol${fmt(totalClosing)}',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue700,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ])
              ],
            ),
          ),

          // --- LOAN LIABILITIES SECTION (IF ANY) ---
          if (hasLoanTransactions) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total Loan Liabilities',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Loans Received',
                              style: const pw.TextStyle(
                                  color: PdfColors.grey600, fontSize: 10)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _formatCurrency(totalLoansReceived, currency),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: paymentColor,
                                fontSize: 12),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Loan Repayments',
                              style: const pw.TextStyle(
                                  color: PdfColors.grey600, fontSize: 10)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _formatCurrency(totalLoanRepayments, currency),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: receiptColor,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        netLoanLiability > 0
                            ? 'Net Outstanding Liability'
                            : 'Loans Fully Repaid',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                      pw.Text(
                        _formatCurrency(netLoanLiability.abs(), currency),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: netLoanLiability > 0
                              ? paymentColor
                              : receiptColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

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
    return pdf;
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
      useRootNavigator: true,
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

  static String _getCurrencyName(String currencyCode) {
    if (currencyCode == 'INR') return 'Indian Rupee';
    if (currencyCode == 'USD') return 'US Dollar';
    if (currencyCode == 'EUR') return 'Euro';
    if (currencyCode == 'GBP') return 'British Pound';
    return currencyCode;
  }
}
