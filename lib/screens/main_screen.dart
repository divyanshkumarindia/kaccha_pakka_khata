import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Added import
import '../state/accounting_model.dart';
import 'home_screen.dart';
import 'saved_reports_screen.dart';
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
  int _currentIndex = 0; // Start with Home (first tab)

  @override
  void initState() {
    super.initState();
    // CRITICAL SECURITY CHECK
    // Ensure user is actually authenticated. If not, kick them out immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = AuthService().currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        // If authenticated, ensure the correct user data is loaded
        final model = Provider.of<AccountingModel>(context, listen: false);
        await model.refreshForUser();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: false,
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 65,
            child: Consumer<AccountingModel>(
              builder: (context, model, child) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildNavItem(0, model.t('nav_home'), Icons.home_outlined,
                        Icons.home_rounded),
                    _buildNavItem(1, model.t('title_saved_reports'),
                        Icons.bookmark_border, Icons.bookmark),
                    _buildNavItem(2, model.t('nav_settings'),
                        Icons.settings_outlined, Icons.settings_rounded),
                  ],
                );
              },
            ),
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
        return const SavedReportsScreen();
      case 2:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }

  Widget _buildNavItem(int index, String label, IconData icon,
      [IconData? activeIcon]) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeColor = const Color(0xFF6366F1); // Indigo Primary
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Expanded(
      child: GestureDetector(
        onTap: () => _handleNavigation(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSelected ? (activeIcon ?? icon) : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(int index) async {
    setState(() {
      _currentIndex = index;
    });
  }
}
