import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Stream auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  // Sign Up with Email
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  // Sign In with Email
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Use the Web Client ID you generated in Google Cloud:
  static const String kWebClientId =
      '524174187471-p6lib92th7u9tu8po0dn2loatu9bnosj.apps.googleusercontent.com';
  // your Android ID
  static const String kAndroidClientId =
      '524174187471-ihpc8l17uiuti2eo0psbco3vh2h6o3ag.apps.googleusercontent.com';

  // Sign In with Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Initialize GoogleSignIn (v7.x uses singleton pattern)
      await GoogleSignIn.instance.initialize(
        serverClientId: kWebClientId,
      );

      // Authenticate using the new v7.x API
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn.instance.authenticate();

      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Token access is now synchronous in v7.x
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      // Exchange the tokens for a Supabase session
      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      print("Supabase Google Sign-In Error: $e");
      rethrow;
    }
  }

  // Reset Password
  Future<void> resetPassword({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // Verify OTP
  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    return await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: type,
    );
  }

  // Resend OTP
  Future<void> resendOTP({required String email}) async {
    await _supabase.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  // Update Password
  Future<UserResponse> updatePassword(String password) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _supabase.auth.signOut();
  }
}
