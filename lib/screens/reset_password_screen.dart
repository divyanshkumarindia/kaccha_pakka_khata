import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../utils/toast_utils.dart';
import '../widgets/premium_back_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      ToastUtils.showErrorToast(context, 'Please fill in both password fields.',
          bottomPadding: 25.0);
      return;
    }

    if (password != confirmPassword) {
      ToastUtils.showErrorToast(context, 'Passwords do not match.',
          bottomPadding: 25.0);
      return;
    }

    if (password.length < 6) {
      ToastUtils.showErrorToast(
          context, 'Password must be at least 6 characters.',
          bottomPadding: 25.0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.updatePassword(password);
      if (mounted) {
        ToastUtils.showSuccessToast(context, 'Password updated successfully!',
            bottomPadding: 25.0);
        // Navigate to Login and clear history
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showErrorToast(context, 'Failed to update password: $e',
            bottomPadding: 25.0);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PremiumBackButton(),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF), // Light Indigo
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.lock_open_rounded,
                          color: Color(0xFF6366F1), // Indigo
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Almost there! Set a new strong password for your account.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: labelColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildLabel(labelColor, 'NEW PASSWORD'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: 'Minimum 6 characters',
                      isDark: isDark,
                      fillColor: inputFillColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      isPassword: true,
                      isVisible: _isPasswordVisible,
                      onVisibilityChanged: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    const SizedBox(height: 20),
                    _buildLabel(labelColor, 'CONFIRM PASSWORD'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm your new password',
                      isDark: isDark,
                      fillColor: inputFillColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      isPassword: true,
                      isVisible: _isConfirmPasswordVisible,
                      onVisibilityChanged: () => setState(() =>
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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
                          : Text(
                              'Update Password',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(Color color, String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    required Color fillColor,
    required Color borderColor,
    required Color textColor,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF9CA3AF),
                ),
                onPressed: onVisibilityChanged,
              )
            : null,
      ),
    );
  }
}
