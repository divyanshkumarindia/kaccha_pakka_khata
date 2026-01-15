import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../state/accounting_model.dart';
import '../utils/toast_utils.dart';
import '../widgets/premium_back_button.dart';
import 'main_screen.dart';

class SignupVerifyOtpScreen extends StatefulWidget {
  final String fullName;
  final String email;
  final String password;

  const SignupVerifyOtpScreen({
    Key? key,
    required this.fullName,
    required this.email,
    required this.password,
  }) : super(key: key);

  @override
  State<SignupVerifyOtpScreen> createState() => _SignupVerifyOtpScreenState();
}

class _SignupVerifyOtpScreenState extends State<SignupVerifyOtpScreen> {
  // Controllers for each digit
  final List<TextEditingController> _controllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  final _authService = AuthService();
  bool _isLoading = false;
  bool _isSuccess = false;

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
    if (otp.length < 4) {
      ToastUtils.showErrorToast(context, 'Please enter the 4-digit code.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Mock verification delay
      await Future.delayed(const Duration(seconds: 2));

      // 2. Try Create Account (but don't block UI flow if it fails for demo)
      try {
        await _authService.signUp(
          email: widget.email,
          password: widget.password,
          fullName: widget.fullName,
        );
      } catch (e) {
        // Ignore backend error for 'just for now' UI demo
        print('Signup service error (ignored for demo): $e');
      }

      if (mounted) {
        // 3. Show Success Animation
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });

        // 4. Wait for animation
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          // SAVE NAME TO APP STATE (Ensures Welcome dialog is skipped)
          final model = Provider.of<AccountingModel>(context, listen: false);
          if (widget.fullName.isNotEmpty) {
            final firstName = widget.fullName.trim().split(' ').first;
            model.setUserName(firstName);
            model.setSkippedNameSetup(true);
          }

          // 5. Navigate to Home Page
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );

          ToastUtils.showSuccessToast(
              context, 'Account created successfully! Welcome.');
        }
      }
    } catch (e) {
      // Should not be reached with the try-catch above
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Custom Back Button
                        const PremiumBackButton(),
                        const SizedBox(height: 32),

                        // Shield Icon
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(
                                  0xFFECFDF5), // Light Green background
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.verified_user_outlined,
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
                                      color: const Color(
                                          0xFFFBBF24), // Amber/Yellow
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
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
                            'We have sent a verification code to your email. Please enter it below.',
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: TextField(
                                    controller: _controllers[index],
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
                                          _focusNodes[index].unfocus(); // Done
                                        }
                                      } else if (value.isEmpty && index > 0) {
                                        _focusNodes[index - 1].requestFocus();
                                      }
                                    },
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: inputFillColor,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide:
                                            BorderSide(color: borderColor),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide:
                                            BorderSide(color: borderColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF10B981),
                                            width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                                if (index < 3) const SizedBox(width: 16),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 40),

                        // Verify Button
                        Center(
                          child: SizedBox(
                            width: 300, // Fixed max width
                            child: ElevatedButton(
                              onPressed: (_isLoading || _isSuccess)
                                  ? null
                                  : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF10B981), // Emerald Green
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                disabledBackgroundColor: _isSuccess
                                    ? const Color(0xFF10B981)
                                    : null, // Keep green when success
                                disabledForegroundColor: _isSuccess
                                    ? Colors.white
                                    : null, // Keep white text
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Account Created',
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Verify & Create Account',
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward,
                                                size: 20),
                                          ],
                                        ),
                            ),
                          ),
                        ),

                        const Spacer(),

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
                                onTap: () {
                                  ToastUtils.showSuccessToast(
                                      context, 'Code resent! (Mock)');
                                },
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
          );
        },
      ),
    );
  }
}
