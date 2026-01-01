import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:jarvis_assistant/screens/jarvis_home_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: "INITIALIZING CORE",
      description:
          "Connecting to the Llama-3 Reasoning Engine for autonomous decision making.",
      icon: Icons.hub_outlined,
      accentColor: Colors.cyanAccent,
    ),
    OnboardingPageData(
      title: "ESTABLISHING MEMORY",
      description:
          "Syncing your personalized Knowledge Vault via Supabase for 100% contextual awareness.",
      icon: Icons.memory_outlined,
      accentColor: Colors.purpleAccent,
    ),
    OnboardingPageData(
      title: "NEURAL LINK ESTABLISHED",
      description: "Ready to act on your behalf. Press the orb to begin.",
      icon: Icons.fingerprint,
      accentColor: const Color(0xFFFFB300), // Amber
    ),
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    HapticFeedback.selectionClick();
  }

  void _skip() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _systemStart() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const JarvisHomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deep charcoal
      body: Stack(
        children: [
          // Background Elements
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [Color(0xFF1E1E24), Colors.black],
                ),
              ),
            ),
          ),

          // Ambient Glow based on current page accent
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            top: _currentPage == 0 ? -100 : (_currentPage == 1 ? 100 : -50),
            left: _currentPage == 0 ? -50 : (_currentPage == 1 ? 200 : 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage].accentColor.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: _pages[_currentPage].accentColor.withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // Main Content Area
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPageContent(_pages[index]);
                    },
                  ),
                ),

                // Footer Controls
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 30.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page Indicators
                      Row(
                        children: List.generate(_pages.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPage == index
                                  ? _pages[index].accentColor
                                  : Colors.white24,
                              boxShadow: _currentPage == index
                                  ? [
                                      BoxShadow(
                                        color: _pages[index].accentColor
                                            .withOpacity(0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                          );
                        }),
                      ),

                      // Action Button
                      if (_currentPage == 2)
                        _buildSystemStartButton()
                      else
                        TextButton(
                          onPressed: _skip,
                          child: Text(
                            "SKIP SEQUENCE >>",
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white54,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(OnboardingPageData data) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container with Glitch/Pulse
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    data.accentColor.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: data.accentColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Icon(data.icon, size: 50, color: data.accentColor)
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    duration: 2000.ms,
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .shimmer(
                    duration: 1000.ms,
                    color: Colors.white.withOpacity(0.5),
                  ),
            ),
          ),

          const SizedBox(height: 60),

          // Glitch Text Title
          Text(
                data.title,
                style: GoogleFonts.orbitron(
                  color: data.accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  shadows: [
                    BoxShadow(
                      color: data.accentColor.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideX(begin: -0.2, end: 0)
              .then(delay: 200.ms)
              .shimmer(duration: 800.ms)
              .tint(color: Colors.white, duration: 200.ms), // Glitch tint

          const SizedBox(height: 20),

          // Glassmorphic Description Card
          ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      data.description,
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .moveY(begin: 20, end: 0),
        ],
      ),
    );
  }

  Widget _buildSystemStartButton() {
    return GestureDetector(
      onTap: _systemStart,
      child:
          Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFFFB300)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "SYSTEM START",
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFFFFB300),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.power_settings_new,
                      color: Color(0xFFFFB300),
                      size: 18,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 1500.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(
                duration: 1500.ms,
                color: const Color(0xFFFFB300).withOpacity(0.3),
              ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}
