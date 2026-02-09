import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added using correct package
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../utils/toast_utils.dart';
import '../widgets/premium_back_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ToastUtils.showErrorToast(context, 'Please enter email and password.',
          bottomPadding: 25.0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(email: email, password: password);
      if (mounted) {
        // Navigate to Home and remove all previous routes
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message = e.message;
        if (message.toLowerCase().contains('email not confirmed')) {
          message = 'Please confirm your email address before logging in.';
        }
        ToastUtils.showErrorToast(context, message, bottomPadding: 25.0);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed: ${e.toString()}';
        if (e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup')) {
          errorMessage =
              'No internet connection. Please check your network settings.';
        }
        ToastUtils.showErrorToast(context, errorMessage, bottomPadding: 25.0);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // 1. Initiate OAuth Flow (launches browser)
      await _authService.signInWithGoogle();

      // 2. Wait for App Resume (User returns from browser)
      // We rely on the WidgetsBindingObserver to detect when the app resumes.
      // Ideally, the deep link triggers the auth state change.
      // However, to satisfy the requirement of "Strictly Login Screen if Back",
      // we do NOT auto-navigate here blindly.
    } catch (e) {
      if (mounted) {
        ToastUtils.showErrorToast(
            context, 'Google Sign-In failed: ${e.toString()}',
            bottomPadding: 25.0);
        setState(() => _isLoading = false);
      }
    }
    // Note: We don't turn off loading immediately if successful,
    // because we are waiting for the lifecycle or stream to kick in.
    // But if we returned from browser via BACK button, we need to reset loading.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionAndNavigate();
    }
  }

  Future<void> _checkSessionAndNavigate() async {
    // Give Supabase a moment to process the deep link if it just arrived
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final user = _authService.currentUser;
    if (user != null) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      // User cancelled or failed
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Wireframe colors
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final labelColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final inputFillColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    final borderColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);

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
                              // Icon
                              Center(
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color:
                                        const Color(0xFFE0E7FF), // Light Blue
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance,
                                    color: Color(0xFF4F46E5), // Indigo
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Title
                              Text(
                                'Welcome Back',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Subtitle
                              Text(
                                'Sign in to access your account',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: labelColor,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Email Label
                              _buildLabel(labelColor, 'EMAIL ADDRESS'),
                              const SizedBox(height: 4),
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'Enter your email',
                                isDark: isDark,
                                fillColor: inputFillColor,
                                borderColor: borderColor,
                                textColor: textColor,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 8),

                              // Password Label
                              _buildLabel(labelColor, 'PASSWORD'),
                              const SizedBox(height: 4),
                              _buildTextField(
                                controller: _passwordController,
                                hintText: 'Enter your password',
                                isDark: isDark,
                                fillColor: inputFillColor,
                                borderColor: borderColor,
                                textColor: textColor,
                                isPassword: true,
                                isVisible: _isPasswordVisible,
                                onVisibilityChanged: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),

                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const ForgotPasswordScreen()),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF6366F1),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Login Button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF6366F1), // Indigo Primary
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
                                        'Log In',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 14),

                              // "Or log in with" Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: borderColor)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      'Or log in with',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: labelColor,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: borderColor)),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Continue with Google Button
                              OutlinedButton(
                                onPressed: _isLoading ? null : _googleSignIn,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: borderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: isDark ? null : Colors.white,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.network(
                                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                                              height: 20,
                                              width: 20, errorBuilder:
                                                  (context, error, stackTrace) {
                                            return RichText(
                                              text: const TextSpan(
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'sans-serif'),
                                                children: [
                                                  TextSpan(
                                                      text: 'G',
                                                      style: TextStyle(
                                                          color: Colors.blue)),
                                                ],
                                              ),
                                            );
                                          }),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Continue with Google',
                                            style: GoogleFonts.roboto(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1F1F1F),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 24),

                              // Footer: Don't have an account? Sign Up
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SignupScreen()),
                                    );
                                  },
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 16.0),
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color: labelColor,
                                        ),
                                        children: [
                                          const TextSpan(
                                              text: "Don't have an account? "),
                                          TextSpan(
                                            text: 'Sign Up',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF6366F1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
        ));
  }

  Widget _buildLabel(Color color, String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize:
            13, // Slightly larger than wireframe caps label, matching normal text
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
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
      obscureText: isPassword && !isVisible,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: const Color(0xFF9CA3AF)),
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
