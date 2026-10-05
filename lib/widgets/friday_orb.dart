import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AssistantState {
  idle,
  listening,
  thinking,
  speaking,
  searchingWeb,
  searchingMemory,
  savingMemory,
  synthesizing,
}

/// J.A.R.V.I.S. holographic HUD orb — amber data-sphere with HUD framing.
/// Fully procedural (no external image assets), matching the JARVIS look.
class FridayOrb extends StatefulWidget {
  final AssistantState state;
  final VoidCallback onTap;
  final double soundLevel;

  const FridayOrb({
    super.key,
    required this.state,
    required this.onTap,
    this.soundLevel = 0.0,
  });

  @override
  State<FridayOrb> createState() => _FridayOrbState();
}

class _FridayOrbState extends State<FridayOrb> with TickerProviderStateMixin {
  static const Color _amber = Color(0xFFFF9500);
  static const Color _amberBright = Color(0xFFFFB347);
  static const Color _amberDeep = Color(0xFFE65100);
  static const Color _amberGlow = Color(0xFFFFCC80);

  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void didUpdateWidget(FridayOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _updateAnimationState();
  }

  void _updateAnimationState() {
    switch (widget.state) {
      case AssistantState.idle:
        _pulseController.duration = const Duration(seconds: 4);
        _rotationController.duration = const Duration(seconds: 24);
        _sweepController.duration = const Duration(seconds: 6);
        break;
      case AssistantState.thinking:
        _pulseController.duration = const Duration(milliseconds: 700);
        _rotationController.duration = const Duration(seconds: 3);
        _sweepController.duration = const Duration(seconds: 2);
        break;
      case AssistantState.listening:
      case AssistantState.speaking:
        _pulseController.duration = const Duration(milliseconds: 900);
        _rotationController.duration = const Duration(seconds: 16);
        _sweepController.duration = const Duration(seconds: 4);
        break;
      case AssistantState.searchingWeb:
        _pulseController.duration = const Duration(milliseconds: 450);
        _rotationController.duration = const Duration(seconds: 1);
        _sweepController.duration = const Duration(milliseconds: 800);
        break;
      case AssistantState.searchingMemory:
      case AssistantState.savingMemory:
        _pulseController.duration = const Duration(milliseconds: 600);
        _rotationController.duration = const Duration(milliseconds: 1200);
        _sweepController.duration = const Duration(seconds: 1);
        break;
      case AssistantState.synthesizing:
        _pulseController.duration = const Duration(milliseconds: 350);
        _rotationController.duration = const Duration(milliseconds: 600);
        _sweepController.duration = const Duration(milliseconds: 500);
        break;
    }
    if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    if (!_rotationController.isAnimating) _rotationController.repeat();
    if (!_sweepController.isAnimating) _sweepController.repeat();
  }

  bool get _isAudioActive =>
      widget.state == AssistantState.listening ||
      widget.state == AssistantState.speaking;

  double get _intensity {
    if (_isAudioActive) return 0.6 + widget.soundLevel * 0.4;
    if (widget.state == AssistantState.thinking ||
        widget.state == AssistantState.searchingWeb ||
        widget.state == AssistantState.synthesizing) {
      return 0.85 + _pulseController.value * 0.15;
    }
    return 0.55 + _pulseController.value * 0.35;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double side =
            math.max(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: side,
            height: side,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _pulseController,
                _rotationController,
                _sweepController,
              ]),
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient bloom
                    _buildBloom(side),

                    // HUD corner brackets + top status bar
                    CustomPaint(
                      size: Size.square(side),
                      painter: _HudFramePainter(
                        color: _amberBright,
                        intensity: _intensity,
                      ),
                    ),

                    // Outer faint containment ring
                    CustomPaint(
                      size: Size.square(side * 0.92),
                      painter: _CircleRingPainter(
                        radius: 0.5,
                        thickness: 0.8,
                        color: _amber.withValues(alpha: 0.25 * _intensity),
                      ),
                    ),

                    // Counter-rotating data orbit ring
                    Transform.rotate(
                      angle: -_rotationController.value * 2 * math.pi,
                      child: CustomPaint(
                        size: Size.square(side * 0.88),
                        painter: _DataOrbitRingPainter(
                          color: _amberBright,
                          intensity: _intensity,
                          seed: 1,
                        ),
                      ),
                    ),

                    // Core data sphere (procedural particles + hot core)
                    Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi * 0.35,
                      child: SizedBox(
                        width: side * 0.72,
                        height: side * 0.72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Procedural particle sphere overlay
                            CustomPaint(
                              size: Size.square(side * 0.72),
                              painter: _DataSpherePainter(
                                rotation: _rotationController.value,
                                sweep: _sweepController.value,
                                intensity: _intensity,
                                color: _amberBright,
                              ),
                            ),

                            // Inner hot core
                            Container(
                              width:
                                  side * 0.14 * (0.9 + _intensity * 0.15),
                              height:
                                  side * 0.14 * (0.9 + _intensity * 0.15),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _amberGlow,
                                    _amber.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _amber.withValues(
                                      alpha: 0.9 * _intensity,
                                    ),
                                    blurRadius: side * 0.1,
                                    spreadRadius: side * 0.02,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sweeping scan arc (matches reference motion indicator)
                    Transform.rotate(
                      angle: _sweepController.value * 2 * math.pi,
                      child: CustomPaint(
                        size: Size.square(side * 0.76),
                        painter: _SweepArcPainter(
                          color: _amberBright,
                          intensity: _intensity * 0.7,
                        ),
                      ),
                    ),

                    // Bottom-right radar gauge
                    Positioned(
                      right: side * 0.06,
                      bottom: side * 0.06,
                      child: CustomPaint(
                        size: Size.square(side * 0.14),
                        painter: _RadarGaugePainter(
                          rotation: _rotationController.value,
                          color: _amberBright,
                          intensity: _intensity,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBloom(double side) {
    return Container(
      width: side * 0.85,
      height: side * 0.85,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _amber.withValues(alpha: 0.35 * _intensity),
            _amberDeep.withValues(alpha: 0.12 * _intensity),
            Colors.transparent,
          ],
          stops: const [0.2, 0.55, 1.0],
        ),
      ),
    );
  }
}

// ─── HUD corner brackets + top status bar ───────────────────────────────────

class _HudFramePainter extends CustomPainter {
  final Color color;
  final double intensity;

  _HudFramePainter({required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;
    final inset = w * 0.08;
    final cornerLen = w * 0.07;

    // Top-left bracket
    canvas.drawLine(Offset(inset, inset), Offset(inset + cornerLen, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset, inset + cornerLen), paint);

    // Top-right bracket
    canvas.drawLine(Offset(w - inset, inset), Offset(w - inset - cornerLen, inset), paint);
    canvas.drawLine(Offset(w - inset, inset), Offset(w - inset, inset + cornerLen), paint);

    // Bottom-left bracket
    canvas.drawLine(Offset(inset, h - inset), Offset(inset + cornerLen, h - inset), paint);
    canvas.drawLine(Offset(inset, h - inset), Offset(inset, h - inset - cornerLen), paint);

    // Top status bar
    final barPaint = Paint()
      ..color = color.withValues(alpha: 0.5 * intensity)
      ..strokeWidth = 0.8;
    final barY = inset * 0.55;
    canvas.drawLine(Offset(w * 0.35, barY), Offset(w * 0.65, barY), barPaint);
    canvas.drawLine(Offset(w * 0.38, barY + 4), Offset(w * 0.62, barY + 4), barPaint);

    // Status dots
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.9 * intensity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5 - 6, barY - 6), 1.5, dotPaint);
    canvas.drawCircle(Offset(w * 0.5 + 6, barY - 6), 1.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _HudFramePainter old) =>
      old.intensity != intensity || old.color != color;
}

// ─── Data orbit ring (fine segmented arcs) ──────────────────────────────────

class _DataOrbitRingPainter extends CustomPainter {
  final Color color;
  final double intensity;
  final int seed;

  _DataOrbitRingPainter({
    required this.color,
    required this.intensity,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 * 0.96;
    final rng = math.Random(seed);

    for (int i = 0; i < 48; i++) {
      final start = (i / 48) * 2 * math.pi;
      final span = (rng.nextDouble() * 0.04 + 0.01);
      final opacity = (rng.nextDouble() * 0.5 + 0.3) * intensity;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = rng.nextDouble() * 1.2 + 0.4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        span,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DataOrbitRingPainter old) =>
      old.intensity != intensity;
}

// ─── Dense particle data-sphere ─────────────────────────────────────────────

class _DataSpherePainter extends CustomPainter {
  final double rotation;
  final double sweep;
  final double intensity;
  final Color color;

  _DataSpherePainter({
    required this.rotation,
    required this.sweep,
    required this.intensity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final rng = math.Random(42);

    for (int i = 0; i < 420; i++) {
      final theta = rng.nextDouble() * 2 * math.pi + rotation * 2 * math.pi;
      final phi = rng.nextDouble() * math.pi;
      final depth = math.sin(phi);
      final x = center.dx + maxR * 0.88 * math.sin(phi) * math.cos(theta);
      final y = center.dy + maxR * 0.88 * math.cos(phi) * 0.95;

      final distFromCenter = math.sqrt(
        math.pow(x - center.dx, 2) + math.pow(y - center.dy, 2),
      );
      if (distFromCenter > maxR * 0.92) continue;

      final alpha = (0.15 + depth * 0.55) * intensity;
      final dotSize = rng.nextDouble() * 1.2 + 0.3;

      if (i % 7 == 0) {
        final len = rng.nextDouble() * 8 + 3;
        final angle = theta + sweep * math.pi;
        final paint = Paint()
          ..color = color.withValues(alpha: alpha * 0.8)
          ..strokeWidth = 0.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + math.cos(angle) * len, y + math.sin(angle) * len),
          paint,
        );
      } else {
        final paint = Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DataSpherePainter old) =>
      old.rotation != rotation ||
      old.sweep != sweep ||
      old.intensity != intensity;
}

// ─── Sweeping translucent arc ───────────────────────────────────────────────

class _SweepArcPainter extends CustomPainter {
  final Color color;
  final double intensity;

  _SweepArcPainter({required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 * 0.92;
    final rect = Rect.fromCircle(center: center, radius: r);

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi / 3,
      colors: [
        Colors.transparent,
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.35 * intensity),
        color.withValues(alpha: 0.15 * intensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.1, 0.25, 0.4, 0.55],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.35
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(rect, -math.pi / 6, math.pi / 2.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SweepArcPainter old) =>
      old.intensity != intensity;
}

// ─── Bottom-right radar gauge ───────────────────────────────────────────────

class _RadarGaugePainter extends CustomPainter {
  final double rotation;
  final Color color;
  final double intensity;

  _RadarGaugePainter({
    required this.rotation,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.6 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, r * i / 3, ringPaint);
    }

    for (int i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final inner = r * 0.75;
      final outer = r * 0.95;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle), center.dy + inner * math.sin(angle)),
        Offset(center.dx + outer * math.cos(angle), center.dy + outer * math.sin(angle)),
        ringPaint,
      );
    }

    final sweepAngle = rotation * 2 * math.pi;
    final needlePaint = Paint()
      ..color = color.withValues(alpha: 0.8 * intensity)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      center,
      Offset(center.dx + r * 0.7 * math.cos(sweepAngle),
          center.dy + r * 0.7 * math.sin(sweepAngle)),
      needlePaint,
    );

    canvas.drawCircle(center, 2, Paint()..color = color.withValues(alpha: intensity));
  }

  @override
  bool shouldRepaint(covariant _RadarGaugePainter old) =>
      old.rotation != rotation || old.intensity != intensity;
}

// ─── Simple circle ring ─────────────────────────────────────────────────────

class _CircleRingPainter extends CustomPainter {
  final double radius;
  final double thickness;
  final Color color;

  _CircleRingPainter({
    required this.radius,
    required this.thickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 * radius;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleRingPainter old) =>
      old.color != color;
}
