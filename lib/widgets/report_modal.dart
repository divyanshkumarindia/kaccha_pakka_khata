import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import '../theme.dart';
import '../utils/report_generator.dart';

class ReportModal extends StatelessWidget {
  const ReportModal({Key? key}) : super(key: key);

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
            onPressed: () {
              Navigator.of(context).pop();
              ReportGenerator.generateAndShareExcel(context, model);
            },
            child: Text(model.t('btn_export_excel'))),
        ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ReportGenerator.printReport(context, model);
            },
            child: Text(model.t('btn_export_pdf'))),
      ],
    );
  }
}
