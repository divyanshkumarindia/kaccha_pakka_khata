import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ToastUtils {
  static OverlayEntry? _currentEntry;

  static void showSuccessToast(BuildContext context, String message,
      {required double bottomPadding}) {
    _showToast(context, message, const Color(0xFF10B981), Icons.check_circle,
        bottomPadding: bottomPadding);
  }

  static void showErrorToast(BuildContext context, String message,
      {required double bottomPadding}) {
    _showToast(context, message, const Color(0xFFEF4444), Icons.error_outline,
        bottomPadding: bottomPadding);
  }

  static void _showToast(
      BuildContext context, String message, Color color, IconData icon,
      {required double bottomPadding}) {
    // If a toast is currently showing, remove it immediately so the new one can take place
    // Or we could let it animate out, but for responsiveness, immediate replacement is often better
    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        color: color,
        icon: icon,
        bottomPadding: bottomPadding,
        onDismiss: () {
          if (_currentEntry != null) {
            _currentEntry!.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;
  final double? bottomPadding;

  const _ToastWidget({
    Key? key,
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
    this.bottomPadding,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ToastWidgetState createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0), // Start from bottom offset
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // Nice spring effect on entry
      reverseCurve: Curves.easeIn, // Smooth exit
    ));

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.bottomPadding ?? 130, // Default to 130 if not specified
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
