import 'package:flutter/material.dart';
import '../widgets/accounting_form.dart';

/// Thin wrapper kept for backwards compatibility and route stability.
/// Delegates to the shared `AccountingForm` implementation.
class AccountingScreen extends StatelessWidget {
  const AccountingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Delegate to the centralized form widget. This keeps routes stable
    // while removing a duplicated large implementation.
    return const AccountingForm(templateKey: 'accounting');
  }
}
