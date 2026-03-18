import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  /// Validate password requirements
  /// - At least one uppercase letter
  /// - At least one lowercase letter
  /// - At least one number
  /// - Maximum 16 characters, minimum 6 characters
  static String? validatePassword(String password) {
    if (password.isEmpty) return "Password is required.";
    if (password.length < 6) return "Password must be at least 6 characters.";
    if (password.length > 16) return "Password must be 16 characters or less.";
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return "Password must contain at least one uppercase letter.";
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return "Password must contain at least one lowercase letter.";
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return "Password must contain at least one number.";
    }
    return null; // Valid
  }

  /// Validate email format
  static String? validateEmail(String email) {
    if (email.isEmpty) return "Email is required.";
    if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$').hasMatch(email)) {
      return "Please enter a valid email address.";
    }
    return null; // Valid
  }

  /// Sign Up with Email & Password (auto-login after signup)
  Future<void> signUp(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      // If Supabase returns a session, user is auto-logged in
      if (response.session == null && response.user?.emailConfirmedAt == null) {
        // Email confirmation is required - sign in directly
        // This handles the case when "Confirm email" is OFF in Supabase
        debugPrint("Signup complete. Session: ${response.session != null}");
      }
    } catch (e) {
      debugPrint("Sign Up Error: $e");
      rethrow;
    }
  }

  /// Sign In with Email & Password
  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint("Sign In Error: $e");
      rethrow;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint("Sign Out Error: $e");
    }
  }

  /// Check if user is logged in
  bool get isLoggedIn => _supabase.auth.currentUser != null;

  /// Get current user ID
  String? get userId => _supabase.auth.currentUser?.id;
}
