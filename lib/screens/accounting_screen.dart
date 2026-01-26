import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../widgets/accounting_form.dart';

/// Thin wrapper kept for backwards compatibility and route stability.
/// Delegates to the shared `AccountingForm` implementation.
class AccountingScreen extends StatelessWidget {
  const AccountingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Delegate to the centralized form widget. This keeps routes stable
    // while removing a duplicated large implementation.
    // Ensure fresh model without persistent descriptions.
    return ChangeNotifierProvider(
      create: (_) => AccountingModel(
        userType: UserType
            .personal, // Default, will update if templateKey changes internal logic?
        // Note: AccountingForm uses templateKey to set titles, but model.userType matters too.
        // Ideally we should pass the correct UserType here.
        // 'accounting' template usually implies generic/personal or handled dynamically.
        shouldLoadFromStorage: false,
      ),
      child: const AccountingForm(templateKey: 'accounting'),
    );
  }
}
