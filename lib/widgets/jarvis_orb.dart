import 'dart:math';
import 'package:flutter/material.dart';

enum AssistantState {
  idle,
  listening,
  thinking,
  speaking,
  // ReAct Pattern States
  searchingWeb, // Actively calling web_search tool
  searchingMemory, // Actively calling search_memory tool
  savingMemory, // Actively calling save_to_memory tool
  synthesizing, // Processing tool results for final answer
}

class JarvisOrb extends StatefulWidget {
  final AssistantState state;
  final VoidCallback onTap;
  final double soundLevel;

  const JarvisOrb({
    super.key,
    required this.state,
    required this.onTap,
    this.soundLevel = 0.0,
  });

  @override
  State<JarvisOrb> createState() => _JarvisOrbState();
}

class _JarvisOrbState extends State<JarvisOrb> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didUpdateWidget(JarvisOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    switch (widget.state) {
      case AssistantState.idle:
        _pulseController.duration = const Duration(seconds: 4);
        _rotationController.duration = const Duration(seconds: 10);
        break;
      case AssistantState.thinking:
        _pulseController.duration = const Duration(milliseconds: 1000);
        _rotationController.duration = const Duration(seconds: 2); // Fast spin
        break;
      case AssistantState.listening:
      case AssistantState.speaking:
        _pulseController.duration = const Duration(milliseconds: 1000);
        _rotationController.duration = const Duration(seconds: 20); // Slow spin
        break;
      // ReAct Pattern States - Dynamic animations for tool execution
      case AssistantState.searchingWeb:
        _pulseController.duration = const Duration(
          milliseconds: 600,
        ); // Fast pulse
        _rotationController.duration = const Duration(
          seconds: 1,
        ); // Very fast spin
        break;
      case AssistantState.searchingMemory:
      case AssistantState.savingMemory:
        _pulseController.duration = const Duration(milliseconds: 800);
        _rotationController.duration = const Duration(milliseconds: 1500);
        break;
      case AssistantState.synthesizing:
        _pulseController.duration = const Duration(
          milliseconds: 400,
        ); // Rapid pulse
        _rotationController.duration = const Duration(
          milliseconds: 800,
        ); // Very fast
        break;
    }
    if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    if (!_rotationController.isAnimating) _rotationController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic color based on state for premium JARVIS feel
    final Color primaryColor = _getStateColor();

    // Determine Scale based on Sound Level (0.0 to 1.0) or Pulse (0.0 to 1.0)
    // If speaking/listening, soundLevel overrides pulse for outer glow
    final isAudioActive =
        widget.state == AssistantState.listening ||
        widget.state == AssistantState.speaking;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 200, // Fixed container size to prevent layout jumps
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Outer Glow (Reacts to Audio & State)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                double scale = isAudioActive
                    ? 1.0 +
                          (widget.soundLevel * 0.5) // Audio Reaction
                    : 1.0 + (_pulseController.value * 0.2); // Idle Breathing

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 120 * scale,
                  height: 120 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withOpacity(0.5),
                        Colors.transparent,
                      ],
                      stops: const [0.2, 1.0],
                    ),
                  ),
                );
              },
            ),

            // Layer 2: Rotating Ring (Middle)
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * pi,
                  child: CustomPaint(
                    size: const Size(100, 100),
                    painter: _RingPainter(color: primaryColor),
                  ),
                );
              },
            ),

            // Layer 3: Inner Core (Solid with dynamic glow)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the appropriate color based on current state
  /// - Amber/Gold for processing states (intense processing feel)
  /// - Cyan for idle, listening, speaking (calm/ready state)
  Color _getStateColor() {
    switch (widget.state) {
      // Processing states = Amber/Gold (Intense Processing)
      case AssistantState.thinking:
      case AssistantState.searchingWeb:
      case AssistantState.searchingMemory:
      case AssistantState.savingMemory:
      case AssistantState.synthesizing:
        return const Color(0xFFFFB300); // Amber/Gold

      // Calm states = Cyan (Ready/Active)
      case AssistantState.idle:
      case AssistantState.listening:
      case AssistantState.speaking:
        return Colors.cyanAccent;
    }
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  _RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw dashed circle
    const double dashWidth = 20;
    const double dashSpace = 20;
    double startAngle = 0;

    while (startAngle < 360) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle * (pi / 180),
        15 * (pi / 180), // Dash length in rad matches visual look
        false,
        paint,
      );
      startAngle += 45; // 8 segments
    }

    // Draw inner thin ring
    final innerPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * 0.8, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
