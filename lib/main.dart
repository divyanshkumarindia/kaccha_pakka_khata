import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'screens/index_screen.dart';
import 'screens/accounting_screen.dart';
import 'screens/accounting_template_screen.dart';
// legacy per-template screens left in the repo; routes now use the shared template screen
import 'state/accounting_model.dart';
import 'models/accounting.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override 
  Widget build(BuildContext context) {
    // We provide a default AccountingModel for safe access; IndexScreen will push a configured model
    return ChangeNotifierProvider<AccountingModel>(
      create: (_) => AccountingModel(userType: UserType.personal),
      child: MaterialApp(
        title: 'My Daily Balance',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const IndexScreen(),
          '/accounting': (context) => const AccountingScreen(),
          // Separate routes per use case
          '/accounting/family': (context) =>
              const AccountingTemplateScreen(templateKey: 'family'),
          '/accounting/business': (context) =>
              const AccountingTemplateScreen(templateKey: 'business'),
          '/accounting/institute': (context) =>
              const AccountingTemplateScreen(templateKey: 'institute'),
          '/accounting/other': (context) =>
              const AccountingTemplateScreen(templateKey: 'other'),
        },
      ),
    );
  }
}
