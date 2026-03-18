import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../services/auth_service.dart';
import 'friday_home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Password validation states (only shown during signup)
  bool get _hasUppercase =>
      RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasLowercase =>
      RegExp(r'[a-z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasValidLength =>
      _passwordController.text.length >= 6 &&
      _passwordController.text.length <= 16;

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate email
    final emailError = AuthService.validateEmail(email);
    if (emailError != null) {
      _showSnack(emailError);
      return;
    }

    // Validate password (strict validation on signup, basic on login)
    if (_isLogin) {
      if (password.isEmpty) {
        _showSnack("Please enter your password.");
        return;
      }
    } else {
      final passwordError = AuthService.validatePassword(password);
      if (passwordError != null) {
        _showSnack(passwordError);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // LOGIN
        await _authService.signIn(email, password);
      } else {
        // SIGNUP → auto-login
        await _authService.signUp(email, password);

        // If Supabase requires email confirmation, the session will be null.
        // If "Confirm email" is OFF, the user is auto-logged in.
        if (!_authService.isLoggedIn) {
          // Try signing in after signup (fallback)
          try {
            await _authService.signIn(email, password);
          } catch (_) {
            _showSnack(
              "Account created! Please check your email to verify, then log in.",
              isError: false,
            );
            setState(() {
              _isLogin = true;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // Navigate to home
      if (mounted && _authService.isLoggedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const FridayHomeScreen()),
        );
      }
    } catch (e) {
      String msg = e.toString().replaceAll("AuthException:", "").trim();
      if (msg.contains("Invalid login credentials")) {
        msg = "Invalid email or password.";
      } else if (msg.contains("User already registered")) {
        msg = "This email is already registered. Please log in.";
        setState(() => _isLogin = true);
      } else if (msg.contains("Email not confirmed")) {
        msg = "Please verify your email first, then log in.";
      }
      _showSnack(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isError
            ? Colors.redAccent.withOpacity(0.9)
            : Colors.green.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [Color(0xFF001524), Colors.black],
              ),
            ),
          ),

          // Animated glow orb
          Positioned(
            top: -100,
            left: -100,
            child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 100,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.2, 1.2),
                  duration: 4.seconds,
                ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Icon(Icons.fingerprint, size: 60, color: Colors.cyanAccent)
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 20),

                    Text(
                      _isLogin ? "WELCOME BACK" : "CREATE ACCOUNT",
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 50),

                    // Form card
                    GlassmorphicContainer(
                          width: double.infinity,
                          height: _isLogin ? 350 : 480,
                          borderRadius: 20,
                          blur: 20,
                          alignment: Alignment.center,
                          border: 1,
                          linearGradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                          borderGradient: LinearGradient(
                            colors: [
                              Colors.cyanAccent.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isLogin ? "LOG IN" : "SIGN UP",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.cyanAccent.withOpacity(0.8),
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Email field
                                _buildInputField(
                                  controller: _emailController,
                                  hint: "Email",
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),

                                const SizedBox(height: 16),

                                // Password field with toggle
                                _buildInputField(
                                  controller: _passwordController,
                                  hint: "Password",
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  onChanged: (_) {
                                    if (!_isLogin) setState(() {});
                                  },
                                ),

                                // Password requirements (only during signup)
                                if (!_isLogin) ...[
                                  const SizedBox(height: 16),
                                  _buildPasswordRequirements(),
                                ],

                                const Spacer(),

                                // Submit button
                                GestureDetector(
                                  onTap: _isLoading ? null : _submit,
                                  child: AnimatedContainer(
                                    duration: 300.ms,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _isLoading
                                          ? Colors.grey.withOpacity(0.2)
                                          : Colors.cyanAccent.withOpacity(0.2),
                                      border: Border.all(
                                        color: _isLoading
                                            ? Colors.transparent
                                            : Colors.cyanAccent
                                                .withOpacity(0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white70,
                                            ),
                                          )
                                        : Text(
                                            _isLogin ? "LOG IN" : "SIGN UP",
                                            style: GoogleFonts.orbitron(
                                              color: Colors.cyanAccent,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 30),

                    // Toggle mode
                    GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: Text.rich(
                        TextSpan(
                          text: _isLogin
                              ? "Don't have an account? "
                              : "Already have an account? ",
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: _isLogin ? "Sign Up" : "Log In",
                              style: GoogleFonts.inter(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Password requirement checklist shown during signup
  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    final items = [
      _PasswordRule("At least one uppercase (A-Z)", _hasUppercase),
      _PasswordRule("At least one lowercase (a-z)", _hasLowercase),
      _PasswordRule("At least one number (0-9)", _hasNumber),
      _PasswordRule(
        "6 – 16 characters (${password.length}/16)",
        _hasValidLength,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    rule.passed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: rule.passed
                        ? Colors.greenAccent
                        : Colors.white24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rule.label,
                    style: GoogleFonts.shareTechMono(
                      color: rule.passed
                          ? Colors.greenAccent
                          : Colors.white30,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: GoogleFonts.shareTechMono(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white30, size: 18),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white30,
                    size: 18,
                  ),
                )
              : null,
          hintText: hint,
          hintStyle: GoogleFonts.shareTechMono(color: Colors.white30),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _PasswordRule {
  final String label;
  final bool passed;
  _PasswordRule(this.label, this.passed);
}
