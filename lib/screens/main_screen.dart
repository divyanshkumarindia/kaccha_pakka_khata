import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import 'home_screen.dart';
import 'saved_reports_screen.dart';
import 'settings_screen.dart';

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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: _getTransitionDuration(_currentIndex),
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
          height: 74,
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
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
                      1, model.t('nav_reports'), Icons.pie_chart_outline),
                  _buildNavItem(
                      2, model.t('nav_settings'), Icons.settings_outlined),
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
        return const SavedReportsScreen();
      case 2:
        return const SettingsScreen();
      default:
        return Container(
          color: isDark ? const Color(0xFF111827) : Colors.white,
        );
    }
  }

  Duration _getTransitionDuration(int index) {
    switch (index) {
      case 1: // Saved Reports
        return const Duration(milliseconds: 200);
      case 2: // Settings
        return const Duration(milliseconds: 400);
      case 0: // Home
      default:
        return const Duration(milliseconds: 300);
    }
  }

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
                height: 2), // Reduced from 8 to 2 to move items downwards
          ],
        ),
      ),
    );
  }
}
