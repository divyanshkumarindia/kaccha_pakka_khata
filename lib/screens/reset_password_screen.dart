import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart'; // For navigation back to login
import '../utils/toast_utils.dart';
import '../widgets/premium_back_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  bool _isSuccess = false;

  // Password Strength Logic (Mock)
  int _strengthLevel = 0; // 0 to 4

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updateStrength);
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updateStrength() {
    final password = _newPasswordController.text;
    setState(() {
      if (password.isEmpty) {
        _strengthLevel = 0;
      } else if (password.length < 6) {
        _strengthLevel = 1;
      } else if (password.length < 8) {
        _strengthLevel = 2;
      } else if (password.length < 10) {
        _strengthLevel = 3;
      } else {
        _strengthLevel = 4;
      }
    });
  }

  Future<void> _resetPassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.isEmpty || confirmPass.isEmpty) {
      ToastUtils.showErrorToast(context, 'Please fill in all fields.');
      return;
    }

    if (newPass != confirmPass) {
      ToastUtils.showErrorToast(context, 'Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    // Buffer 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    }

    // Show success message for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // Navigate close all and go to Login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final labelColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
    final inputFillColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: cardColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Back Button
              const PremiumBackButton(),
              const SizedBox(height: 32),

              // Shield Icon (Same as Verify OTP)
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5), // Light Green background
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined, // Reuse check shield
                        color: Color(0xFF10B981), // Emerald Green
                        size: 50,
                      ),
                      // Small yellow dot indicator
                      Positioned(
                        top: 16,
                        right: 18,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24), // Amber/Yellow
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Reset Password',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Please create a new, strong password for your account.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: labelColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // New Password Label
              Text(
                'NEW PASSWORD',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // New Password Input
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                style: TextStyle(color: textColor),
                decoration: _inputDecoration(
                  hintText: 'Enter new password',
                  icon: Icons.lock_outline,
                  isObscured: _obscureNewPassword,
                  toggleVisibility: () {
                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                  },
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                  iconColor: labelColor,
                ),
              ),
              const SizedBox(height: 24),

              // Confirm Password Label
              Text(
                'CONFIRM PASSWORD',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Confirm Password Input
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: TextStyle(color: textColor),
                decoration: _inputDecoration(
                  hintText: 'Confirm new password',
                  icon: Icons.lock_outline,
                  isObscured: _obscureConfirmPassword,
                  toggleVisibility: () {
                    setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                  iconColor: labelColor,
                ),
              ),
              const SizedBox(height: 24),

              // Strength Indicator
              Row(
                children: [
                  Expanded(child: _buildStrengthBar(0, _strengthLevel)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStrengthBar(1, _strengthLevel)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStrengthBar(2, _strengthLevel)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStrengthBar(3, _strengthLevel)),
                  const SizedBox(width: 16),
                  Text(
                    _getStrengthText(_strengthLevel),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStrengthColor(_strengthLevel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Reset Button
              ElevatedButton(
                onPressed: (_isLoading || _isSuccess) ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: _isSuccess
                      ? const Color(0xFF10B981)
                      : null, // Keep green when success
                  disabledForegroundColor:
                      _isSuccess ? Colors.white : null, // Keep white text
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : _isSuccess
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Password Reset Successfully',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.check, size: 20),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Reset Password',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle, size: 20),
                            ],
                          ),
              ),

              const SizedBox(height: 32),

              // Cancel
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Cancel and Go Back',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthBar(int index, int level) {
    Color color = const Color(0xFFE5E7EB); // Gray default
    if (level > index) {
      if (level == 1) color = Colors.red;
      if (level == 2) color = Colors.orange;
      if (level == 3) color = Colors.blue;
      if (level == 4) color = const Color(0xFF10B981); // Green
    }

    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _getStrengthText(int level) {
    switch (level) {
      case 0:
        return '';
      case 1:
        return 'WEAK';
      case 2:
        return 'FAIR';
      case 3:
        return 'GOOD';
      case 4:
        return 'STRONG';
      default:
        return '';
    }
  }

  Color _getStrengthColor(int level) {
    switch (level) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      case 4:
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required bool isObscured,
    required VoidCallback toggleVisibility,
    required Color fillColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.outfit(color: iconColor),
      prefixIcon: Icon(icon, color: iconColor, size: 20),
      suffixIcon: IconButton(
        icon: Icon(
          isObscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: iconColor,
          size: 20,
        ),
        onPressed: toggleVisibility,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color(0xFF10B981), width: 1.5), // Green focus
      ),
    );
  }
}
