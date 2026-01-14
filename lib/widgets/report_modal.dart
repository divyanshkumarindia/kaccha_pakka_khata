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
          pw.Text(model.t('label_opening_balances'),
              style: pw.TextStyle(fontSize: 16)),
          pw.Bullet(
              text:
                  '${model.t('balance_title_cash')}: ${AppTheme.formatCurrency(model.openingCash, currency: model.currency)}'),
          pw.Bullet(
              text:
                  '${model.t('balance_title_bank')}: ${AppTheme.formatCurrency(model.openingBank, currency: model.currency)}'),
          pw.Bullet(
              text:
                  '${model.t('balance_title_other')}: ${AppTheme.formatCurrency(model.openingOther, currency: model.currency)}'),
          pw.SizedBox(height: 8),
          pw.Text('Receipts', style: pw.TextStyle(fontSize: 16)),
          pw.TableHelper.fromTextArray(
            context: ctx,
            data: <List<String>>[
              <String>[
                model.t('label_account'),
                '${model.t('label_amount')} (${model.currency})'
              ],
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
              <String>[
                model.t('label_account'),
                '${model.t('label_amount')} (${model.currency})'
              ],
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
                  '${model.t('label_total_receipts')}: ${AppTheme.formatCurrency(model.receiptsTotal, currency: model.currency)}'),
          pw.Paragraph(
              text:
                  '${model.t('label_total_payments')}: ${AppTheme.formatCurrency(model.paymentsTotal, currency: model.currency)}'),
          pw.Paragraph(
              text:
                  '${model.t('label_report_closing_balance')}: ${AppTheme.formatCurrency(model.netBalance, currency: model.currency)}'),
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
            Text(
                '${model.t('label_total_receipts')}: ${AppTheme.formatCurrency(model.receiptsTotal, currency: model.currency)}'),
            Text(
                '${model.t('label_total_payments')}: ${AppTheme.formatCurrency(model.paymentsTotal, currency: model.currency)}'),
            Text(
                '${model.t('label_report_closing_balance')}: ${AppTheme.formatCurrency(model.netBalance, currency: model.currency)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(model.t('btn_close'))),
        TextButton(
            onPressed: () => _exportExcel(context, model),
            child: Text(model.t('btn_export_excel'))),
        ElevatedButton(
            onPressed: () => _printPdf(context, model),
            child: Text(model.t('btn_export_pdf'))),
      ],
    );
  }
}
