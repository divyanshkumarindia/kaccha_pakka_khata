import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/accounting_model.dart';
import '../models/accounting.dart';
import 'category_reports_screen.dart';

class SavedReportsScreen extends StatelessWidget {
  const SavedReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<AccountingModel>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(model.t('title_saved_reports')),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Account Category',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'View your saved balance sheets and history for each specific account type.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isWide = width > 600;
                final cardWidth = isWide ? (width - 24) / 2 : width;
                final aspectRatio = isWide ? 1.5 : 1.1;

                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: _buildCategoryCard(
                          context,
                          title: model.t('card_personal'),
                          icon: Icons.people_outline,
                          color: const Color(0xFF60A5FA), // Blue for Personal
                          bgColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                          isActive: model.userType == UserType.personal,
                          onTap: () => _navigateToReports(
                            context,
                            model.t('card_personal'),
                            'Personal',
                            const Color(0xFF60A5FA),
                          ),
                          isDark: isDark,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: _buildCategoryCard(
                          context,
                          title: model.t('card_business'),
                          icon: Icons.store_outlined,
                          color: const Color(0xFF10B981), // Green for Business
                          bgColor: const Color(0xFFECFDF5),
                          borderColor: const Color(0xFFA7F3D0),
                          isActive: model.userType == UserType.business,
                          onTap: () => _navigateToReports(
                            context,
                            model.t('card_business'),
                            'Business',
                            const Color(0xFF10B981),
                          ),
                          isDark: isDark,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: _buildCategoryCard(
                          context,
                          title: model.t('card_institute'),
                          icon: Icons.school_outlined,
                          color:
                              const Color(0xFF8B5CF6), // Purple for Institute
                          bgColor: const Color(0xFFF5F3FF),
                          borderColor: const Color(0xFFDDD6FE),
                          isActive: model.userType == UserType.institute,
                          onTap: () => _navigateToReports(
                            context,
                            model.t('card_institute'),
                            'Institute',
                            const Color(0xFF8B5CF6),
                          ),
                          isDark: isDark,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: _buildCategoryCard(
                          context,
                          title: model.t('card_other'),
                          icon: Icons.category_outlined,
                          color: const Color(
                              0xFFF59E0B), // Orange/Yellow for Other
                          bgColor: const Color(0xFFFFFBEB),
                          borderColor: const Color(0xFFFDE68A),
                          isActive: model.userType == UserType.other,
                          onTap: () => _navigateToReports(
                            context,
                            model.t('card_other'),
                            'Other',
                            const Color(0xFFF59E0B),
                          ),
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToReports(
      BuildContext context, String title, String useCase, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryReportsScreen(
          categoryName: title,
          useCaseType: useCase,
          categoryColor: color,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    // If dark mode, adjust colors to be darker
    final cardBg = isDark ? color.withOpacity(0.15) : bgColor;
    final cardBorder = isDark ? color.withOpacity(0.3) : borderColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24), // Larger radius like mockup
          border: Border.all(
            color: isActive ? color : cardBorder,
            width: isActive ? 3 : 2, // Thicker border for active
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: color,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title +
                          ' Reports', // Appending 'Reports' as per mockup logic
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Positioned(
                bottom: 24, // Positioned at bottom center relative to card
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
