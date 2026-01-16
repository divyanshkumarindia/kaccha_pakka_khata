import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/toast_utils.dart';
import '../widgets/premium_back_button.dart';
import 'login_screen.dart';

class ResetPasswordVerifyScreen extends StatefulWidget {
  final String email;

  const ResetPasswordVerifyScreen({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<ResetPasswordVerifyScreen> createState() =>
      _ResetPasswordVerifyScreenState();
}

class _ResetPasswordVerifyScreenState extends State<ResetPasswordVerifyScreen> {
  // Phase 1: OTP Entry
  final List<TextEditingController> _otpControllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  // Phase 2: Password Entry
  final _newPasswordController = TextEditingController();
  bool _isPasswordVisible = false;

  bool _isOtpVerified = false; // Phase Switch

  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _otpControllers) controller.dispose();
    for (var node in _focusNodes) node.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // Step 1: Verify Code matches Recovery Type
  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((e) => e.text).join();
    if (otp.length < 4) {
      ToastUtils.showErrorToast(context, 'Please enter the 4-digit code.',
          bottomPadding: 25.0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.recovery, // Critical: Recovery Type
      );

      // If successful, user is now logged in with a temporary session
      // Switch UI to entering new password
      if (mounted) {
        setState(() {
          _isOtpVerified = true;
          _isLoading = false;
        });
        ToastUtils.showSuccessToast(context, 'Code verified! Set new password.',
            bottomPadding: 25.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showErrorToast(context, 'Verification failed: $e',
            bottomPadding: 25.0);
      }
    }
  }

  // Step 2: Update Password
  Future<void> _updatePassword() async {
    final newPass = _newPasswordController.text.trim();
    if (newPass.length < 6) {
      ToastUtils.showErrorToast(
          context, 'Password must be at least 6 characters.',
          bottomPadding: 25.0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.updatePassword(newPass);

      if (mounted) {
        ToastUtils.showSuccessToast(context, 'Password updated successfully!',
            bottomPadding: 130.0);

        // Navigate to Login (or Home, but Login keeps it clean to re-auth if needed)
        // User is actually logged in now, but let's send them to Login for clear flow
        // Or send to Home? The requirement says "Ensure the user is navigated to the home screen upon successful verification" (for signup).
        // For reset, "After successful verification, show a New Password field".
        // After setting password, usually go to login.

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showErrorToast(context, 'Failed to update password: $e',
            bottomPadding: 25.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shared UI values
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);

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
                    const SizedBox(height: 32),

                    // --- HEADER ---
                    Text(
                      _isOtpVerified ? 'Set New Password' : 'Verify Reset Code',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOtpVerified
                          ? 'Enter your new password below.'
                          : 'Enter the 4-digit code sent to ${widget.email}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- CONTENT SWITCHER ---
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isOtpVerified
                          ? _buildPasswordInput(isDark, borderColor, textColor)
                          : _buildOtpInput(isDark, borderColor, textColor),
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

  Widget _buildOtpInput(bool isDark, Color borderColor, Color textColor) {
    return Column(
      key: const ValueKey('otp_input'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        if (index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        } else {
                          _focusNodes[index].unfocus();
                        }
                      } else if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF10B981), width: 1.5),
                      ),
                    ),
                  ),
                ),
                if (index < 3) const SizedBox(width: 16),
              ],
            );
          }),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : const Center(
                  child: Text(
                    'Verify Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPasswordInput(bool isDark, Color borderColor, Color textColor) {
    return Column(
      key: const ValueKey('password_input'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _newPasswordController,
          obscureText: !_isPasswordVisible,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'New Password',
            filled: true,
            fillColor:
                isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _updatePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5), // Indigo
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : const Center(
                  child: Text(
                    'Update Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ],
    );
  }
}
