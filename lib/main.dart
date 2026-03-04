import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'services/auth_service.dart';
import 'state/accounting_model.dart';
import 'state/app_state.dart';
import 'models/accounting.dart';
import 'screens/accounting_template_screen.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

void main() async {
  debugPrint('🚀 App Launching...');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ WidgetsInitialized');

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ DotEnv Loaded');
  } catch (e) {
    debugPrint('❌ DotEnv Failed: $e');
  }

  // Initialize Supabase
  try {
    debugPrint('⏳ Initializing Supabase...');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    debugPrint('✅ Supabase Initialized');

    // Supabase Auth State Change Listener for OneSignal
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      try {
        if (event == AuthChangeEvent.signedIn && session != null) {
          final userId = session.user.id;
          OneSignal.login(userId);
          debugPrint('✅ OneSignal login successful for user: $userId');
        } else if (event == AuthChangeEvent.signedOut) {
          OneSignal.logout();
          debugPrint('✅ OneSignal logout successful');
        }
      } catch (e) {
        debugPrint('❌ OneSignal auth sync error: $e');
      }
    });
  } catch (e) {
    debugPrint('❌ Supabase initialization error: $e');
  }

  // Initialize OneSignal
  try {
    debugPrint('⏳ Initializing OneSignal...');
    OneSignal.initialize("888349b2-9a69-4914-a58e-7fc9d9d22877");
    // Request permission safely when app is ready
    OneSignal.Notifications.requestPermission(true);
    debugPrint('✅ OneSignal Initialized');
  } catch (e) {
    debugPrint('❌ OneSignal initialization error: $e');
  }

  debugPrint('🚀 Calling runApp...');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          debugPrint('🏗️ Creating AccountingModel');
          return AccountingModel(
            userType: UserType.personal,
            shouldLoadFromStorage: false, // Wait for MainScreen to load
          );
        }),
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider<AuthService>(create: (_) {
          debugPrint('🏗️ Creating AuthService');
          return AuthService();
        }),
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
      title: 'Kaccha Pakka Khata',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
      home: StreamBuilder<AuthState>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While waiting for the stream to emit the first event,
            // check the current synchronous session as a hint,
            // but prefer showing a loader or Welcome to prevent authorized flash.
            final user = AuthService().currentUser;
            if (user != null) {
              return const MainScreen();
            }
            return const WelcomeScreen();
          }

          final session = snapshot.data?.session;
          if (session != null) {
            return const MainScreen();
          }
          return const WelcomeScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const MainScreen(),
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
