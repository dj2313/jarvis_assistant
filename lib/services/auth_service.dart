import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  /// Sign Up with Email & Password
  Future<void> signUp(String email, String password) async {
    try {
      await _supabase.auth.signUp(email: email, password: password);
      // Depending on Supabase settings, email confirmation might be required.
    } catch (e) {
      debugPrint("Sign Up Error: $e");
      rethrow;
    }
  }

  /// Sign In with Email & Password
  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Sign In Error: $e");
      rethrow;
    }
  }

  /// Resend Confirmation Email
  Future<void> resendEmailConfirmation(String email) async {
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      debugPrint("Resend Error: $e");
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
