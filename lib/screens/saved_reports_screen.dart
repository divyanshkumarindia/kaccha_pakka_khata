import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_daily_balance_flutter/state/app_state.dart';
import 'package:my_daily_balance_flutter/state/accounting_model.dart';
import 'category_reports_screen.dart';

class SavedReportsScreen extends StatelessWidget {
  const SavedReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final model = Provider.of<AccountingModel>(context);
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Saved Reports'),
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
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),

            // Navigation Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2, // Taller buttons for the hub
              children: [
                _buildCategoryButton(
                  context,
                  '${model.t('card_personal')} Reports',
                  'Personal',
                  const Color(0xFF00C853),
                  Icons.groups_rounded,
                  isDark,
                  isCurrentSession: appState.activeUseCaseString == 'Personal',
                ),
                _buildCategoryButton(
                  context,
                  '${model.t('card_business')} Reports',
                  'Business',
                  const Color(0xFF2563EB),
                  Icons.store_rounded,
                  isDark,
                  isCurrentSession: appState.activeUseCaseString == 'Business',
                ),
                _buildCategoryButton(
                  context,
                  '${model.t('card_institute')} Reports',
                  'Institute',
                  const Color(0xFF7C3AED),
                  Icons.school_rounded,
                  isDark,
                  isCurrentSession: appState.activeUseCaseString == 'Institute',
                ),
                _buildCategoryButton(
                  context,
                  '${model.t('card_other')} Reports',
                  'Other',
                  const Color(0xFFF59E0B),
                  Icons.category_rounded,
                  isDark,
                  isCurrentSession: appState.activeUseCaseString == 'Other',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(
    BuildContext context,
    String label,
    String useCaseType,
    Color color,
    IconData icon,
    bool isDark, {
    bool isCurrentSession = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryReportsScreen(
              categoryName: label,
              useCaseType: useCaseType,
              categoryColor: color,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isCurrentSession
              ? color.withValues(alpha: 0.15)
              : (isDark
                  ? color.withValues(alpha: 0.08)
                  : color.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrentSession
                ? color
                : (isDark
                    ? color.withValues(alpha: 0.3)
                    : color.withValues(alpha: 0.2)),
            width: isCurrentSession ? 2 : 1.5,
          ),
          boxShadow: isCurrentSession
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
                height: 1.1,
              ),
            ),
            if (isCurrentSession) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
