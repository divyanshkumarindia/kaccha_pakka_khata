import 'package:flutter/material.dart';

class PremiumBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const PremiumBackButton({Key? key, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF);
    final iconColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 42, // Slightly smaller as requested
            height: 42,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
