import 'package:flutter/material.dart';
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          const SavedReportsScreen(),
          const SettingsScreen(),
          Container(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            child: const Center(
              child: Text('Profile Coming Soon'),
            ),
          ),
        ],
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
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNavItem(0, 'HOME', Icons.home_outlined),
              _buildNavItem(1, 'REPORTS', Icons.pie_chart_outline),
              _buildNavItem(2, 'SETTINGS', Icons.settings_outlined),
              _buildNavItem(3, 'PROFILE', Icons.person_outline),
            ],
          ),
        ),
      ),
    );
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
                height: 8), // Adjusted spacing to lift text above dot
          ],
        ),
      ),
    );
  }
}
