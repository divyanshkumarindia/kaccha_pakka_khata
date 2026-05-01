import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../theme.dart';

class CsvExportService {
  /// Generate and share a detailed CSV containing all individual transactions
  static Future<void> generateAndShareDetailedCsv(
      BuildContext context, AccountingModel model) async {
    try {
      _showLoadingDialog(context, 'Generating Detailed Excel...');

      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy').format(now);
      final currency = model.currency;
      final currencySymbol = AppTheme.getCurrencySymbol(currency);

      // Build CSV content
      final StringBuffer csv = StringBuffer();

      // Helper to add CSV row
      void addRow(List<String> cells) {
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
      addRow(['Detailed Transaction Log - $dateStr']);
      addRow(['Currency:', '$currency ($currencySymbol)']);
      addRow([]);

      // Headers
      addRow([
        'Type',
        'Category',
        'Entry Description',
        'Row Particulars',
        'Cash Amount',
        'Bank Amount',
        'Total Amount'
      ]);

      // Helper to process entries
      void processEntries(Map<String, List<TransactionEntry>> accounts, String typeLabel, Map<String, String> labels) {
        for (final account in accounts.entries) {
          final categoryKey = account.key;
          final categoryName = labels[categoryKey] ?? categoryKey;

          for (final entry in account.value) {
            for (final row in entry.rows) {
              if (row.cash == 0 && row.bank == 0 && entry.description.isEmpty && row.particulars.isEmpty) {
                continue; // Skip completely empty rows
              }

              final total = row.cash + row.bank;
              addRow([
                typeLabel,
                categoryName,
                entry.description,
                row.particulars,
                row.cash.toStringAsFixed(2),
                row.bank.toStringAsFixed(2),
                total.toStringAsFixed(2),
              ]);
            }
          }
        }
      }

      // Process Receipts
      processEntries(model.receiptAccounts, 'Receipt (Income)', model.receiptLabels);

      // Process Payments
      processEntries(model.paymentAccounts, 'Payment (Expense)', model.paymentLabels);

      addRow([]);
      
      // Add Opening and Closing Balances at the bottom for reference
      addRow(['Summary']);
      addRow(['Opening Cash', model.openingCash.toStringAsFixed(2)]);
      addRow(['Opening Bank', model.openingBank.toStringAsFixed(2)]);
      addRow(['Opening Other', model.openingOther.toStringAsFixed(2)]);
      
      final openingBalance = model.openingCash + model.openingBank + model.openingOther;
      addRow(['Total Opening Balance', openingBalance.toStringAsFixed(2)]);
      
      final closingBalance = openingBalance + model.netBalance;
      addRow(['Closing Balance', closingBalance.toStringAsFixed(2)]);

      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be closed
        }
      }

      final fileName = 'detailed_transactions_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
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
              content: Text('Detailed Report downloaded successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        // Share for Mobile/Desktop
        final box = context.findRenderObject() as RenderBox?;
        final bytes = utf8.encode(csvString);
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [
            XFile.fromData(
              Uint8List.fromList(bytes),
              name: fileName,
              mimeType: 'text/csv',
            )
          ],
          subject: 'Detailed Transactions - ${model.firmName}',
          sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6366F1)),
              const SizedBox(width: 24),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
