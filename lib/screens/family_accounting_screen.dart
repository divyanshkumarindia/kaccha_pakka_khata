import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import '../widgets/accounting_form.dart';

/// Thin wrapper kept for backwards compatibility and explicit route name.
/// Delegates all UI and state to `AccountingForm` so the canonical
/// implementation lives in a single place.
class FamilyAccountingScreen extends StatelessWidget {
  const FamilyAccountingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Provide a fresh model that DOES NOT load from storage/prefs.
    // This ensures description fields start empty/default.
    return ChangeNotifierProvider(
      create: (_) => AccountingModel(
        userType: UserType.personal,
        shouldLoadFromStorage: false,
      ),
      child: const AccountingForm(templateKey: 'family'),
    );
  }
}
