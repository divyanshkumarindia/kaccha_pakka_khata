import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_screen.dart';
import '../utils/toast_utils.dart';
import '../widgets/premium_back_button.dart';
import '../services/auth_service.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  final OtpType type;

  const VerifyOtpScreen({
    Key? key,
    required this.email,
    required this.type,
  }) : super(key: key);

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  // Controllers for each digit
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    String otp = _controllers.map((e) => e.text).join();
    if (otp.length < 6) {
      ToastUtils.showErrorToast(context, 'Please enter the 6-digit code.',
          bottomPadding: 25.0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.verifyOTP(
        email: widget.email,
        token: otp,
        type: widget.type,
      );

      if (mounted) {
        ToastUtils.showSuccessToast(context, 'OTP Verified!',
            bottomPadding: 25.0);

        if (widget.type == OtpType.signup) {
          // Navigate to Home
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else if (widget.type == OtpType.recovery) {
          // Navigate to Reset Password
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ResetPasswordScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showErrorToast(
            context, 'Verification failed: ${e.toString()}',
            bottomPadding: 25.0);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resendCode() async {
    try {
      await _authService.resendOTP(
        email: widget.email,
        type: widget.type,
      );
      if (mounted) {
        ToastUtils.showSuccessToast(context, 'Code resent to ${widget.email}!',
            bottomPadding: 25.0);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showErrorToast(context, 'Failed to resend code: $e',
            bottomPadding: 25.0);
      }
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
                    // Custom Back Button
                    const PremiumBackButton(),
                    const SizedBox(height: 10),

                    // Shield Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFECFDF5), // Light Green background
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF10B981), // Emerald Green
                              size: 40,
                            ),
                            // Small yellow dot indicator
                            Positioned(
                              top: 16,
                              right: 18,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFFBBF24), // Amber/Yellow
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
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
                      'Verification Code',
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
                        'We have sent a verification code to ${widget.email}. Please enter it below.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: labelColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // OTP Input Row
                    LayoutBuilder(builder: (context, constraints) {
                      double itemWidth = (constraints.maxWidth - (5 * 8)) / 6;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return Row(
                            children: [
                              SizedBox(
                                width: itemWidth.clamp(45, 60),
                                height: 60,
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      if (index < 5) {
                                        _focusNodes[index + 1].requestFocus();
                                      } else {
                                        _focusNodes[index].unfocus();
                                        _verifyOtp(); // Auto-verify on last digit
                                      }
                                    } else if (value.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: inputFillColor,
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF10B981), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                              if (index < 5) const SizedBox(width: 8),
                            ],
                          );
                        }),
                      );
                    }),
                    const SizedBox(height: 32),

                    // Verify Button
                    Center(
                      child: SizedBox(
                        width: double.infinity, // Fixed max width
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF10B981), // Emerald Green
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Verify',
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.verified, size: 22),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Resend Code
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Didn't receive the code?",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _isLoading ? null : _resendCode,
                            child: Text(
                              'Resend Code',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981), // Green
                              ),
                            ),
                          ),
                        ],
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
}
