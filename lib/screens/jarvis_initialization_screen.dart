import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'jarvis_home_screen.dart';

class JarvisInitializationScreen extends StatefulWidget {
  const JarvisInitializationScreen({super.key});

  @override
  State<JarvisInitializationScreen> createState() =>
      _JarvisInitializationScreenState();
}

class _JarvisInitializationScreenState extends State<JarvisInitializationScreen>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _dotController;
  late Animation<double> _dotScale;

  late AnimationController _textController;
  late Animation<double> _textOpacity;

  // State
  final List<String> _logs = [];
  bool _showCircle = false;
  String _loadingText = "";

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startBootSequence();
  }

  void _initAnimations() {
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _dotScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeOutExpo),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_textController);
  }

  Future<void> _startBootSequence() async {
    // 1. Dot Appears
    await Future.delayed(const Duration(milliseconds: 100)); // Faster start
    if (!mounted) return;
    await _dotController.forward();

    // 2. Expand to Circle
    if (!mounted) return;
    setState(() => _showCircle = true);
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. System Initializing Text
    if (!mounted) return;
    await _typewritterEffect("SYSTEM INITIALIZING...");
    if (!mounted) return;
    _textController.forward();

    // 4. Run Checks (Faster)
    if (!mounted) return;
    await _addLog("ESTABLISHING NEURAL LINK...", 400);
    if (!mounted) return;
    await _addLog("[OK] GROQ_API_HANDSHAKE_COMPLETE", 300);
    if (!mounted) return;
    await _addLog("[OK] SUPABASE_MEMORY_VAULT_ONLINE", 300);
    if (!mounted) return;
    await _addLog("CALIBRATING AUDITORY SENSORS...", 400);
    if (!mounted) return;
    await _addLog("[OK] VOICE_MODULE_READY (EN-GB)", 300);

    // 5. Finalize
    if (!mounted) return;
    await _addLog("ALL SYSTEMS OPERATIONAL.", 800);

    if (!mounted) return;
    _navigateToHome();
  }

  Future<void> _typewritterEffect(String text) async {
    setState(() => _loadingText = "");
    for (int i = 0; i < text.length; i++) {
      setState(() => _loadingText += text[i]);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _addLog(String text, int delayMs) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    setState(() => _logs.add(text));
  }

  void _navigateToHome() {
    Navigator.of(
      context,
    ).pushReplacement(_CircularRevealRoute(const JarvisHomeScreen()));
  }

  @override
  void dispose() {
    _dotController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Center Animation
          AnimatedBuilder(
            animation: _dotController,
            builder: (context, child) {
              return Transform.scale(
                scale: _showCircle ? 20.0 : _dotScale.value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _showCircle ? Colors.transparent : Colors.white,
                    border: _showCircle
                        ? Border.all(
                            color: Colors.cyanAccent.withOpacity(0.5),
                            width: 0.5,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),

          // Log Output
          Positioned(
            bottom: 100,
            left: 40,
            child: FadeTransition(
              opacity: _textOpacity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loadingText,
                    style: GoogleFonts.shareTechMono(
                      color: Colors.cyanAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._logs.map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Icon(
                            log.contains("[OK]") ? Icons.check : Icons.hub,
                            color: log.contains("[OK]")
                                ? Colors.greenAccent
                                : Colors.cyan.withOpacity(0.5),
                            size: 12,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            log,
                            style: GoogleFonts.shareTechMono(
                              color: log.contains("[OK]")
                                  ? Colors.greenAccent.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Circular Reveal Route
class _CircularRevealRoute extends PageRouteBuilder {
  final Widget page;

  _CircularRevealRoute(this.page)
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 1000),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var screenSize = MediaQuery.of(context).size;
          return ClipPath(
            clipper: _CircleRevealClipper(animation.value),
            child: child,
          );
        },
      );
}

class _CircleRevealClipper extends CustomClipper<Path> {
  final double progress;

  _CircleRevealClipper(this.progress);

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        (size.width > size.height ? size.width : size.height) * 1.5;
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: maxRadius * progress));
    return path;
  }

  @override
  bool shouldReclip(_CircleRevealClipper oldClipper) =>
      progress != oldClipper.progress;
}
