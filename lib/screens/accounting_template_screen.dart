import 'package:flutter/material.dart';
import '../widgets/accounting_form.dart';

/// Template route that renders the shared `AccountingForm` widget.
/// Each template key (family, business, institute, other) is passed through
/// so `AccountingForm` can adapt labels/defaults if necessary.
class AccountingTemplateScreen extends StatelessWidget {
  final String templateKey;
  final String? customTitle;
  final String? customPageId;
  final Map<String, dynamic>? initialState; // For editing existing reports
  final String? reportId; // For updating existing report

  const AccountingTemplateScreen({
    Key? key,
    required this.templateKey,
    this.customTitle,
    this.customPageId,
    this.initialState,
    this.reportId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AccountingForm(
      templateKey: templateKey,
      customTitle: customTitle,
      customPageId: customPageId,
      initialState: initialState,
      reportId: reportId,
    );
  }
}
