// lib/screens/splash_screen.dart - PRIMORDIAL RAINBOW OOZE EMERGENCE
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'game_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Simplified animation controllers
  late AnimationController _oozeController;
  late AnimationController _textController;
  late AnimationController _bubblesController;

  // Animation values
  late Animation<double> _oozeSpread;
  late Animation<double> _textEmergence;
  late Animation<double> _textScale;
  late Animation<double> _bubbleAnimation;

  // Ooze particles
  List<OozeParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    // PHASE 1: Ooze spreads (2 seconds)
    _oozeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // PHASE 2: Text emerges from ooze (1.5 seconds)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // PHASE 3: Bubbles throughout (3 seconds)
    _bubblesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Initialize animations
    _oozeSpread = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _oozeController, curve: Curves.easeOut),
    );

    _textEmergence = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.elasticOut),
    );

    _textScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.elasticOut),
    );

    _bubbleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bubblesController, curve: Curves.linear),
    );

    // Generate ooze particles
    _generateOozeParticles();

    // Start the emergence sequence
    _startEmergenceSequence();
  }

  void _generateOozeParticles() {
    final random = math.Random();
    _particles = List.generate(50, (index) {
      return OozeParticle(
        angle: random.nextDouble() * 2 * math.pi,
        speed: 0.3 + random.nextDouble() * 0.7,
        size: 5.0 + random.nextDouble() * 15.0,
        color: _getOozeColor(random),
        delay: random.nextDouble() * 0.5,
      );
    });
  }

  Color _getOozeColor(math.Random random) {
    final oozeColors = [
      Colors.purple.shade400,
      Colors.pink.shade400,
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.red.shade400,
      Colors.cyan.shade400,
      Colors.yellow.shade400,
    ];
    return oozeColors[random.nextInt(oozeColors.length)];
  }

  Future<void> _startEmergenceSequence() async {
    // Start ooze spread
    _oozeController.forward();

    // Start bubbles
    await Future.delayed(const Duration(milliseconds: 500));
    // Bubbles already repeating

    // Text emerges from ooze
    await Future.delayed(const Duration(milliseconds: 1000));
    _textController.forward();

    // Navigate to main screen
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const GameSelectionScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _oozeController.dispose();
    _textController.dispose();
    _bubblesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // PRIMORDIAL OOZE BACKGROUND
          AnimatedBuilder(
            animation: _oozeController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.shade900.withOpacity(_oozeSpread.value * 0.8),
                      Colors.pink.shade800.withOpacity(_oozeSpread.value * 0.6),
                      Colors.blue.shade900.withOpacity(_oozeSpread.value * 0.4),
                      Colors.black,
                    ],
                    center: Alignment.center,
                    radius: _oozeSpread.value * 2.0,
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              );
            },
          ),

          // OOZE PARTICLES
          AnimatedBuilder(
            animation: _oozeController,
            builder: (context, child) {
              return CustomPaint(
                painter: OozePainter(
                  particles: _particles,
                  progress: _oozeSpread.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // BUBBLES EFFECT
          AnimatedBuilder(
            animation: _bubblesController,
            builder: (context, child) {
              return CustomPaint(
                painter: BubblesPainter(
                  animation: _bubbleAnimation.value,
                  oozeProgress: _oozeSpread.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // EMERGING TEXT
          Center(
            child: AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textEmergence.value,
                  child: Transform.scale(
                    scale: _textScale.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _textEmergence.value) * 50),
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.red.withOpacity(_textEmergence.value),
                            Colors.orange.withOpacity(_textEmergence.value),
                            Colors.yellow.withOpacity(_textEmergence.value),
                            Colors.green.withOpacity(_textEmergence.value),
                            Colors.blue.withOpacity(_textEmergence.value),
                            Colors.indigo.withOpacity(_textEmergence.value),
                            Colors.purple.withOpacity(_textEmergence.value),
                            Colors.pink.withOpacity(_textEmergence.value),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          'MINUTE MADNESS',
                          style: GoogleFonts.creepster(
                            fontSize: 42,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.9),
                                blurRadius: 12,
                                offset: const Offset(4, 4),
                              ),
                              Shadow(
                                color: Colors.red.withOpacity(0.7),
                                blurRadius: 16,
                                offset: const Offset(-3, -3),
                              ),
                              Shadow(
                                color: Colors.purple.withOpacity(0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Ooze particle data class
class OozeParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double delay;

  OozeParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.delay,
  });
}

// Ooze particle painter
class OozePainter extends CustomPainter {
  final List<OozeParticle> particles;
  final double progress;

  OozePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = math.max(size.width, size.height) * 0.6;

    for (final particle in particles) {
      final particleProgress = math.max(0.0, progress - particle.delay);
      if (particleProgress <= 0) continue;

      final distance = particleProgress * particle.speed * maxDistance;
      final x = center.dx + math.cos(particle.angle) * distance;
      final y = center.dy + math.sin(particle.angle) * distance;

      final opacity = math.max(0.0, 1.0 - particleProgress);

      // Ooze blob effect
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity * 0.7)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 0.5);

      canvas.drawCircle(Offset(x, y), particle.size, paint);

      // Inner glow
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(opacity * 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), particle.size * 0.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(OozePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Bubbles painter
class BubblesPainter extends CustomPainter {
  final double animation;
  final double oozeProgress;

  BubblesPainter({
    required this.animation,
    required this.oozeProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (oozeProgress < 0.3) return; // Only show bubbles after ooze starts spreading

    final random = math.Random(42); // Fixed seed for consistent bubbles

    for (int i = 0; i < 20; i++) {
      final bubblePhase = (animation + i * 0.1) % 1.0;
      final x = random.nextDouble() * size.width;
      final startY = size.height + 50;
      final endY = -50;
      final y = startY + (endY - startY) * bubblePhase;

      final bubbleSize = 3 + random.nextDouble() * 8;
      final opacity = math.sin(bubblePhase * math.pi) * oozeProgress * 0.6;

      if (opacity <= 0) continue;

      final bubbleColor = Color.lerp(
        Colors.white,
        _getBubbleColor(random),
        0.3,
      )!;

      final paint = Paint()
        ..color = bubbleColor.withOpacity(opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bubbleSize * 0.3);

      canvas.drawCircle(Offset(x, y), bubbleSize, paint);
    }
  }

  Color _getBubbleColor(math.Random random) {
    final colors = [
      Colors.purple.shade300,
      Colors.pink.shade300,
      Colors.blue.shade300,
      Colors.cyan.shade300,
    ];
    return colors[random.nextInt(colors.length)];
  }

  @override
  bool shouldRepaint(BubblesPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.oozeProgress != oozeProgress;
  }
}