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
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 30),
                            // Logo/Icon
                            Center(
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(
                                      0xFFE0E7FF), // Light Blue/Indigo
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.lock_open_rounded,
                                  color: Color(0xFF4F46E5), // Indigo
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Reset Password',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Almost there! Set a new strong password for your account.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: labelColor,
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildLabel(labelColor, 'NEW PASSWORD'),
                            const SizedBox(height: 4),
                            _buildTextField(
                              controller: _passwordController,
                              hintText: 'Minimum 6 characters',
                              isDark: isDark,
                              fillColor: inputFillColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              isPassword: true,
                              isVisible: _isPasswordVisible,
                              onVisibilityChanged: () => setState(() =>
                                  _isPasswordVisible = !_isPasswordVisible),
                            ),
                            const SizedBox(height: 8),
                            _buildLabel(labelColor, 'CONFIRM PASSWORD'),
                            const SizedBox(height: 4),
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
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _updatePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Update Password',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Positioned(
              top: 10,
              left: 20,
              child: PremiumBackButton(),
            ),
          ],
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
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
      obscureText: isPassword && !isVisible,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
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
