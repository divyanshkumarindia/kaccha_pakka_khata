import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/foundation.dart';
import 'dart:io';

class AuthService {
  // Singleton Pattern
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  // Private client instance
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthService._internal() {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      // Listen for Sign In (including initial session and post-signup)
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        if (session != null) {
          try {
            final userId = session.user.id;
            // Check if user_data row exists to avoid overwriting with empty data
            // (Using maybeSingle to safely check existence)
            final existingData = await _supabase
                .from('user_data')
                .select()
                .eq('user_id', userId)
                .maybeSingle();

            if (existingData == null) {
              // Insert new row if missing
              await _supabase.from('user_data').insert({
                'user_id': userId,
                'data': {}, // Initialize empty JSON
                'updated_at': DateTime.now().toIso8601String(),
              });
              print("User Data row created for $userId");
            }
          } catch (e) {
            // Silently ignore or log error (e.g., duplicated concurrent insert)
            if (kDebugMode && e is! SocketException) {
              debugPrint("Error syncing user_data: $e");
            }
          }
        }
      }
    });
  }

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
  // Google Client IDs from Environment
  static String get kWebClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  static String get kAndroidClientId =>
      dotenv.env['GOOGLE_ANDROID_CLIENT_ID'] ?? '';
  static String get kIosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

  // Sign In with Google
  Future<bool> signInWithGoogle() async {
    try {
      // Use Supabase OAuth Flow (Web-based)
      // This handles both Web and Mobile (via deep link)
      final bool result = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://callback',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        queryParams: {
          'access_type': 'offline',
          'prompt': 'select_account',
          if (kIsWeb) 'client_id': kWebClientId,
        },
      );

      return result;
    } catch (e) {
      if (kDebugMode) debugPrint("Supabase Google Sign-In Error: $e");
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
