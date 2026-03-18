import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Ambient Idle Mode - Premium screensaver overlay
/// Optimized with lazy particle rendering and efficient repaint boundaries

class AmbientIdleOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final String? currentWeather;
  final String? nextEvent;
  final int? memoryCount;

  const AmbientIdleOverlay({
    super.key,
    required this.onDismiss,
    this.currentWeather,
    this.nextEvent,
    this.memoryCount,
  });

  @override
  State<AmbientIdleOverlay> createState() => _AmbientIdleOverlayState();
}

class _AmbientIdleOverlayState extends State<AmbientIdleOverlay>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late Timer _timeUpdateTimer;
  String _currentTime = '';
  String _currentDate = '';

  // Lazy particle system - generate on demand
  late final List<_AmbientParticle> _particles;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Only create particles once - lazy init
    _particles = List.generate(
      25, // Reduced count for performance
      (_) => _AmbientParticle(_random),
    );

    // Particle animation - 60fps target
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Pulse animation for orb
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Update time every second (lazy timer)
    _updateTime();
    _timeUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTime(),
    );
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = _formatTime(now);
      _currentDate = _formatDate(now);
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime dt) {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${days[dt.weekday % 7]} ${dt.day} ${months[dt.month - 1]}';
  }

  @override
  void dispose() {
    _particleController.dispose();
    _pulseController.dispose();
    _timeUpdateTimer.cancel();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // 1. Particle background (isolated repaint)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _AmbientParticlePainter(
                        particles: _particles,
                        progress: _particleController.value,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),

            // 2. Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Main content
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Animated Friday Orb (simplified for ambient)
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulseController.value * 0.1);
                            final opacity =
                                0.6 + (_pulseController.value * 0.4);
                            return Container(
                              width: 100 * scale,
                              height: 100 * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withOpacity(
                                      opacity * 0.5,
                                    ),
                                    blurRadius: 60,
                                    spreadRadius: 20,
                                  ),
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(
                                      opacity * 0.3,
                                    ),
                                    blurRadius: 100,
                                    spreadRadius: 40,
                                  ),
                                ],
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.cyanAccent.withOpacity(opacity),
                                    Colors.blue.withOpacity(opacity * 0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Time display
                      Text(
                        _currentTime,
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 8,
                        ),
                      ).animate().fadeIn(duration: 800.ms),

                      const SizedBox(height: 8),

                      // Date display
                      Text(
                        _currentDate,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white54,
                          fontSize: 16,
                          letterSpacing: 4,
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 200.ms),

                      const SizedBox(height: 40),

                      // Quick info cards (lazy render)
                      _buildInfoCards(),

                      const Spacer(flex: 3),

                      // Tap to wake hint
                      Text(
                            'TAP ANYWHERE TO WAKE',
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white24,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn(duration: 1500.ms)
                          .then()
                          .fadeOut(duration: 1500.ms),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    // Only build cards if data is available (lazy)
    final hasData =
        widget.currentWeather != null ||
        widget.nextEvent != null ||
        widget.memoryCount != null;

    if (!hasData) return const SizedBox.shrink();

    return RepaintBoundary(
      child:
          Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (widget.currentWeather != null)
                            _buildInfoItem(
                              Icons.cloud_outlined,
                              widget.currentWeather!,
                              Colors.cyan,
                            ),
                          if (widget.nextEvent != null)
                            _buildInfoItem(
                              Icons.event_outlined,
                              widget.nextEvent!,
                              Colors.purple,
                            ),
                          if (widget.memoryCount != null)
                            _buildInfoItem(
                              Icons.memory,
                              '${widget.memoryCount} nodes',
                              Colors.teal,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 800.ms, delay: 400.ms)
              .slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.8)),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

// ============================================================================
// PARTICLE SYSTEM - Optimized for ambient mode
// ============================================================================

class _AmbientParticle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double opacity;
  Color color;

  _AmbientParticle(math.Random random)
    : x = random.nextDouble(),
      y = random.nextDouble(),
      size = random.nextDouble() * 2 + 1,
      speedX = (random.nextDouble() - 0.5) * 0.002,
      speedY = (random.nextDouble() - 0.5) * 0.002,
      opacity = random.nextDouble() * 0.3 + 0.1,
      color = [
        Colors.cyan,
        Colors.blue,
        Colors.purple,
        Colors.teal,
      ][random.nextInt(4)];

  void update() {
    x += speedX;
    y += speedY;

    // Wrap around
    if (x < 0) x = 1;
    if (x > 1) x = 0;
    if (y < 0) y = 1;
    if (y > 1) y = 0;
  }
}

class _AmbientParticlePainter extends CustomPainter {
  final List<_AmbientParticle> particles;
  final double progress;

  _AmbientParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Update and draw particles
    for (final particle in particles) {
      particle.update();

      // Pulsing opacity based on progress
      final pulseOpacity =
          particle.opacity *
          (0.7 + 0.3 * math.sin(progress * math.pi * 2 + particle.x * 10));

      paint.color = particle.color.withOpacity(pulseOpacity);

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }

    // Draw connecting lines for nearby particles (lazy - only some)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < particles.length; i += 2) {
      for (int j = i + 1; j < particles.length; j += 2) {
        final p1 = particles[i];
        final p2 = particles[j];
        final dx = (p1.x - p2.x) * size.width;
        final dy = (p1.y - p2.y) * size.height;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < 150) {
          final opacity = (1 - distance / 150) * 0.15;
          linePaint.color = Colors.cyan.withOpacity(opacity);
          canvas.drawLine(
            Offset(p1.x * size.width, p1.y * size.height),
            Offset(p2.x * size.width, p2.y * size.height),
            linePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientParticlePainter oldDelegate) {
    return true; // Always repaint for animation
  }
}

// ============================================================================
// IDLE DETECTOR - Mixin for screens that use ambient mode
// ============================================================================

mixin AmbientIdleMixin<T extends StatefulWidget> on State<T> {
  Timer? _idleTimer;
  bool _isAmbientMode = false;

  // Configurable idle timeout (default 2 minutes)
  Duration get idleTimeout => const Duration(minutes: 2);

  // Override to provide ambient overlay data
  String? get ambientWeather => null;
  String? get ambientNextEvent => null;
  int? get ambientMemoryCount => null;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  /// Call this on any user interaction to reset the idle timer
  void resetIdleTimer() {
    if (_isAmbientMode) {
      _exitAmbientMode();
    } else {
      _resetIdleTimer();
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _enterAmbientMode);
  }

  void _enterAmbientMode() {
    if (!mounted) return;
    setState(() => _isAmbientMode = true);
    HapticFeedback.lightImpact();
  }

  void _exitAmbientMode() {
    if (!mounted) return;
    setState(() => _isAmbientMode = false);
    _resetIdleTimer();
  }

  /// Build the ambient overlay - call this in your build method's Stack
  Widget buildAmbientOverlay() {
    if (!_isAmbientMode) return const SizedBox.shrink();

    return AmbientIdleOverlay(
      onDismiss: _exitAmbientMode,
      currentWeather: ambientWeather,
      nextEvent: ambientNextEvent,
      memoryCount: ambientMemoryCount,
    ).animate().fadeIn(duration: 500.ms);
  }
}
