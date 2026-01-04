import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import '../state/accounting_model.dart';
import 'package:provider/provider.dart';
import '../theme.dart';

class ReportModal extends StatelessWidget {
  const ReportModal({Key? key}) : super(key: key);

  Future<void> _printPdf(BuildContext context, AccountingModel model) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (pw.Context ctx) => [
          pw.Header(
              level: 0,
              child:
                  pw.Text(model.firmName, style: pw.TextStyle(fontSize: 24))),
          pw.Paragraph(
              text:
                  'Period: ${model.duration.toString().split('.').last} ${model.periodDate}'),
          pw.SizedBox(height: 8),
          pw.Text('Opening Balances', style: pw.TextStyle(fontSize: 16)),
          pw.Bullet(text: 'Cash: ₹${model.openingCash.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Bank: ₹${model.openingBank.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Other: ₹${model.openingOther.toStringAsFixed(2)}'),
          pw.SizedBox(height: 8),
          pw.Text('Receipts', style: pw.TextStyle(fontSize: 16)),
          pw.TableHelper.fromTextArray(
            context: ctx,
            data: <List<String>>[
              <String>['Account', 'Amount (₹)'],
              ...model.receiptAccounts.entries
                  .expand((e) => e.value.map((entry) => [
                        e.key,
                        model.calculateEntriesTotal([entry]).toStringAsFixed(2)
                      ]))
                  .toList(),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Payments', style: pw.TextStyle(fontSize: 16)),
          pw.TableHelper.fromTextArray(
            context: ctx,
            data: <List<String>>[
              <String>['Account', 'Amount (₹)'],
              ...model.paymentAccounts.entries
                  .expand((e) => e.value.map((entry) => [
                        e.key,
                        model.calculateEntriesTotal([entry]).toStringAsFixed(2)
                      ]))
                  .toList(),
            ],
          ),
          pw.Divider(),
          pw.Paragraph(
              text:
                  'Total Receipts: ${AppTheme.formatCurrency(model.receiptsTotal)}'),
          pw.Paragraph(
              text:
                  'Total Payments: ${AppTheme.formatCurrency(model.paymentsTotal)}'),
          pw.Paragraph(
              text:
                  'Closing Balance: ${AppTheme.formatCurrency(model.netBalance)}'),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  void _exportExcel(BuildContext context, AccountingModel model) {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];

    sheet.appendRow([TextCellValue('Firm'), TextCellValue(model.firmName)]);
    sheet.appendRow([
      TextCellValue('Period'),
      TextCellValue(model.duration.toString().split('.').last),
      TextCellValue(model.periodDate)
    ]);
    sheet.appendRow(<CellValue?>[]);

    sheet.appendRow([
      TextCellValue('Opening Balances'),
      TextCellValue(''),
      TextCellValue('')
    ]);
    sheet
        .appendRow([TextCellValue('Cash'), DoubleCellValue(model.openingCash)]);
    sheet
        .appendRow([TextCellValue('Bank'), DoubleCellValue(model.openingBank)]);
    sheet.appendRow(
        [TextCellValue('Other'), DoubleCellValue(model.openingOther)]);
    sheet.appendRow(<CellValue?>[]);

    sheet.appendRow([TextCellValue('Receipts'), TextCellValue('Amount')]);
    for (var e in model.receiptAccounts.entries) {
      final amount = model.calculateEntriesTotal(e.value);
      sheet.appendRow([TextCellValue(e.key), DoubleCellValue(amount)]);
    }
    sheet.appendRow(<CellValue?>[]);
    sheet.appendRow([TextCellValue('Payments'), TextCellValue('Amount')]);
    for (var e in model.paymentAccounts.entries) {
      final amount = model.calculateEntriesTotal(e.value);
      sheet.appendRow([TextCellValue(e.key), DoubleCellValue(amount)]);
    }

    final _ = excel.encode();
    // For now, we will print a message (writing files to disk requires platform-specific code)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Excel buffer created (not saved to disk in this demo)')));
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<AccountingModel>(context, listen: false);

    return AlertDialog(
      title: Text(model.firmName.isEmpty ? 'Report' : model.firmName),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'For period: ${model.duration.toString().split('.').last} ${model.periodDate}'),
            const SizedBox(height: 8),
            Text('Total Receipts: ₹${model.receiptsTotal.toStringAsFixed(2)}'),
            Text('Total Payments: ₹${model.paymentsTotal.toStringAsFixed(2)}'),
            Text('Closing Balance: ₹${model.netBalance.toStringAsFixed(2)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close')),
        TextButton(
            onPressed: () => _exportExcel(context, model),
            child: const Text('Export Excel')),
        ElevatedButton(
            onPressed: () => _printPdf(context, model),
            child: const Text('Export PDF')),
      ],
    );
  }
}
