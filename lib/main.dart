import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'state/accounting_model.dart';
import 'models/accounting.dart';
import 'screens/accounting_template_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AccountingModel(userType: UserType.personal)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Balance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      routes: {
        '/accounting/family': (context) =>
            const AccountingTemplateScreen(templateKey: 'family'),
        '/accounting/business': (context) =>
            const AccountingTemplateScreen(templateKey: 'business'),
        '/accounting/institute': (context) =>
            const AccountingTemplateScreen(templateKey: 'institute'),
        '/accounting/other': (context) =>
            const AccountingTemplateScreen(templateKey: 'other'),
      },
    );
  }
}
