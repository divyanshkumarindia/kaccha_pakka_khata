import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// Main entry screen with bottom navigation bar
/// This replaces IndexScreen as the app entry point
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // CRITICAL SECURITY CHECK
    // Ensure user is actually authenticated. If not, kick them out immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthService().currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _buildPage(_currentIndex, isDark),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 80,
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Dark Navy Blue
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Consumer<AccountingModel>(
            builder: (context, model, child) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNavItem(0, model.t('nav_home'), Icons.home_outlined),
                  _buildNavItem(
                      1, model.t('nav_settings'), Icons.settings_outlined),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int index, bool isDark) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }

  // _getTransitionDuration method removed as it's no longer used

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF60A5FA) : Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(
                height: 8), // Adjusted spacing to lift text above dot
          ],
        ),
      ),
    );
  }
}
