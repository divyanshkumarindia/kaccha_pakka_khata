import 'package:flutter/material.dart';
import '../widgets/accounting_form.dart';

/// Template route that renders the shared `AccountingForm` widget.
/// Each template key (family, business, institute, other) is passed through
/// so `AccountingForm` can adapt labels/defaults if necessary.
class AccountingTemplateScreen extends StatelessWidget {
  final String templateKey;
  const AccountingTemplateScreen({Key? key, required this.templateKey})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AccountingForm(templateKey: templateKey);
  }
}
