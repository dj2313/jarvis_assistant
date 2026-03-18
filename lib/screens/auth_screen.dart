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

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Please enter credentials, Agent.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(email, password);
      } else {
        await _authService.signUp(email, password);
        _showSnack("Identity created. Please Log In.", isError: false);
        // Switch to login after signup
        setState(() {
          _isLogin = true;
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const FridayHomeScreen()),
        );
      }
    } catch (e) {
      String msg = e.toString().replaceAll("AuthException:", "").trim();
      if (msg.contains("Invalid login credentials")) {
        msg = "Access Denied. Identity mismatch.";
        _showSnack(msg);
      } else if (msg.contains("Email not confirmed")) {
        msg = "Identity pending verification. Check your transmission (Email).";
        _showSnack(
          msg,
          action: SnackBarAction(
            label: "RESEND",
            textColor: Colors.cyanAccent,
            onPressed: () => _resendConfirmation(email),
          ),
        );
      } else {
        _showSnack(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resendConfirmation(String email) async {
    try {
      await _authService.resendEmailConfirmation(email);
      _showSnack("Transmission resent, Agent.", isError: false);
    } catch (e) {
      _showSnack("Error re-sending: ${e.toString()}");
    }
  }

  void _showSnack(String msg, {bool isError = true, SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.shareTechMono(color: Colors.white),
        ),
        backgroundColor: isError
            ? Colors.redAccent.withOpacity(0.8)
            : Colors.green.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        action: action,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: Stack(
        children: [
          // Background - Static Deep Space
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [Color(0xFF001524), Colors.black],
              ),
            ),
          ),

          // Animated Glow Orb
          Positioned(
            top: -100,
            left: -100,
            child:
                Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent.withOpacity(0.2),
                        image: const DecorationImage(
                          image: NetworkImage(
                            "https://i.imgur.com/4q7R1.png",
                          ), // Subtle texture if needed, or just color
                          opacity: 0.0,
                        ),
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
                    // LOGO / IDENTITY
                    Icon(Icons.fingerprint, size: 60, color: Colors.cyanAccent)
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 20),

                    Text(
                      "IDENTITY VERIFICATION",
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 50),

                    // FORM CARD
                    GlassmorphicContainer(
                          width: double.infinity,
                          height: 380,
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
                                  _isLogin
                                      ? "ACCESS TERMINAL"
                                      : "NEW AGENT REGISTRATION",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.cyanAccent.withOpacity(0.8),
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // Email Input
                                _buildInputField(
                                  controller: _emailController,
                                  hint: "Agent ID (Email)",
                                  icon: Icons.person_outline,
                                ),

                                const SizedBox(height: 16),

                                // Password Input
                                _buildInputField(
                                  controller: _passwordController,
                                  hint: "Access Code",
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                ),

                                const Spacer(),

                                // Submit Button
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
                                            : Colors.cyanAccent.withOpacity(
                                                0.5,
                                              ),
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
                                            _isLogin
                                                ? "INITIALIZE LINK"
                                                : "REGISTER",
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

                    // Toggle Mode
                    GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: Text.rich(
                        TextSpan(
                          text: _isLogin
                              ? "First time here? "
                              : "Already verified? ",
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: _isLogin
                                  ? "Create Identity"
                                  : "Access Terminal",
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.shareTechMono(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white30, size: 18),
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
