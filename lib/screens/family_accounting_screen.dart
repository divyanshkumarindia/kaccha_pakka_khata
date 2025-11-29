import 'package:flutter/material.dart';
import '../widgets/accounting_form.dart';

/// Thin wrapper kept for backwards compatibility and explicit route name.
/// Delegates all UI and state to `AccountingForm` so the canonical
/// implementation lives in a single place.
class FamilyAccountingScreen extends StatelessWidget {
  const FamilyAccountingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AccountingForm(templateKey: 'family');
  }
}
