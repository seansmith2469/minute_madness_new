// lib/screens/splash_screen.dart - ULTRA EXPLOSIVE BIG BANG ANIMATION
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

  // ULTRA EXPLOSIVE ANIMATION CONTROLLERS
  late AnimationController _bigBangController;
  late AnimationController _explosionController;
  late AnimationController _textFormationController;
  late AnimationController _colorExplosionController;
  late AnimationController _particleController;
  late AnimationController _shockwaveController;
  late AnimationController _chaosController;
  late AnimationController _universeController;

  // Animation values
  late Animation<double> _bigBangScale;
  late Animation<double> _explosionRadius;
  late Animation<double> _textOpacity;
  late Animation<double> _textScale;
  late Animation<double> _colorIntensity;
  late Animation<double> _particleSpread;
  late Animation<double> _shockwaveExpansion;
  late Animation<double> _chaosIntensity;
  late Animation<double> _universeFormation;

  // MASSIVE particle system
  List<CosmicParticle> _particles = [];
  List<ColorWave> _colorWaves = [];
  List<EnergyBurst> _energyBursts = [];

  @override
  void initState() {
    super.initState();

    // PHASE 1: Initial singularity (0.3s)
    _bigBangController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // PHASE 2: MASSIVE EXPLOSION (1.2s)
    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // PHASE 3: Color chaos formation (1.5s)
    _colorExplosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // PHASE 4: Shockwaves (1.0s)
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // PHASE 5: Pure chaos (1.5s)
    _chaosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // PHASE 6: Universe formation (2.0s)
    _universeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // PHASE 7: Text formation (1.5s)
    _textFormationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Particle system (longer duration for full effect)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // Initialize animations
    _bigBangScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bigBangController, curve: Curves.easeIn),
    );

    _explosionRadius = Tween<double>(begin: 0.0, end: 3.5).animate(
      CurvedAnimation(parent: _explosionController, curve: Curves.easeOut),
    );

    _colorIntensity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _colorExplosionController, curve: Curves.easeInOut),
    );

    _shockwaveExpansion = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shockwaveController, curve: Curves.easeOut),
    );

    _chaosIntensity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chaosController, curve: Curves.easeInOut),
    );

    _universeFormation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _universeController, curve: Curves.easeInOut),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textFormationController, curve: Curves.easeIn),
    );

    _textScale = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(parent: _textFormationController, curve: Curves.elasticOut),
    );

    _particleSpread = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );

    // Generate MASSIVE cosmic particle systems
    _generateCosmicParticles();
    _generateColorWaves();
    _generateEnergyBursts();

    // Start the ULTRA EXPLOSIVE BIG BANG sequence!
    _startBigBangSequence();
  }

  void _generateCosmicParticles() {
    final random = math.Random();
    _particles = List.generate(300, (index) { // INCREASED: 300 particles!
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 0.3 + random.nextDouble() * 3.0; // More speed variation
      final size = 1.0 + random.nextDouble() * 12.0; // Bigger particles
      final color = _getCosmicColor(random);
      final depth = random.nextDouble(); // Z-depth for layering

      return CosmicParticle(
        angle: angle,
        speed: speed,
        size: size,
        color: color,
        depth: depth,
      );
    });
  }

  void _generateColorWaves() {
    final random = math.Random();
    _colorWaves = List.generate(15, (index) { // More waves
      return ColorWave(
        startAngle: random.nextDouble() * 2 * math.pi,
        speed: 0.5 + random.nextDouble() * 1.5,
        width: 20 + random.nextDouble() * 60,
        color: _getCosmicColor(random),
        intensity: 0.3 + random.nextDouble() * 0.7,
      );
    });
  }

  void _generateEnergyBursts() {
    final random = math.Random();
    _energyBursts = List.generate(25, (index) { // Energy bursts
      return EnergyBurst(
        angle: random.nextDouble() * 2 * math.pi,
        length: 50 + random.nextDouble() * 200,
        thickness: 2 + random.nextDouble() * 8,
        color: _getCosmicColor(random),
        delay: random.nextDouble() * 0.5,
      );
    });
  }

  Color _getCosmicColor(math.Random random) {
    final cosmicColors = [
      Colors.red.shade900,
      Colors.orange.shade800,
      Colors.yellow.shade600,
      Colors.green.shade700,
      Colors.blue.shade800,
      Colors.indigo.shade700,
      Colors.purple.shade800,
      Colors.pink.shade700,
      Colors.cyan.shade600,
      Colors.lime.shade700,
      Colors.deepOrange.shade800,
      Colors.deepPurple.shade900,
      Colors.amber.shade700,
      Colors.teal.shade700,
      Colors.redAccent.shade700,
      Colors.purpleAccent.shade700,
    ];
    return cosmicColors[random.nextInt(cosmicColors.length)];
  }

  Future<void> _startBigBangSequence() async {
    // PHASE 1: Singularity appears
    await Future.delayed(const Duration(milliseconds: 100));
    _bigBangController.forward();

    // PHASE 2: MASSIVE EXPLOSION!
    await Future.delayed(const Duration(milliseconds: 300));
    _explosionController.forward();
    _particleController.forward();

    // PHASE 3: Shockwaves
    await Future.delayed(const Duration(milliseconds: 400));
    _shockwaveController.forward();

    // PHASE 4: Color chaos emerges
    await Future.delayed(const Duration(milliseconds: 600));
    _colorExplosionController.forward();

    // PHASE 5: Pure chaos
    await Future.delayed(const Duration(milliseconds: 800));
    _chaosController.forward();

    // PHASE 6: Universe formation
    await Future.delayed(const Duration(milliseconds: 1200));
    _universeController.forward();

    // PHASE 7: Text forms from the chaos
    await Future.delayed(const Duration(milliseconds: 1500));
    _textFormationController.forward();

    // PHASE 8: Navigate to main screen
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const GameSelectionScreen(),
          transitionDuration: const Duration(milliseconds: 1000),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut)
                ),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _bigBangController.dispose();
    _explosionController.dispose();
    _textFormationController.dispose();
    _colorExplosionController.dispose();
    _particleController.dispose();
    _shockwaveController.dispose();
    _chaosController.dispose();
    _universeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // COSMIC BACKGROUND WITH UNIVERSE FORMATION
          AnimatedBuilder(
            animation: _universeController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(_universeFormation.value * 0.05),
                      Colors.blue.shade900.withOpacity(_universeFormation.value * 0.2),
                      Colors.purple.shade900.withOpacity(_universeFormation.value * 0.4),
                      Colors.indigo.shade900.withOpacity(_universeFormation.value * 0.6),
                      Colors.black.withOpacity(0.8 + _universeFormation.value * 0.2),
                      Colors.black,
                    ],
                    center: Alignment.center,
                    radius: _explosionRadius.value * 1.2,
                    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                  ),
                ),
              );
            },
          ),

          // CHAOS LAYER
          AnimatedBuilder(
            animation: _chaosController,
            builder: (context, child) {
              return CustomPaint(
                painter: ChaosPainter(
                  chaosIntensity: _chaosIntensity.value,
                  time: _particleController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // SHOCKWAVE SYSTEM
          AnimatedBuilder(
            animation: _shockwaveController,
            builder: (context, child) {
              return CustomPaint(
                painter: ShockwavePainter(
                  expansion: _shockwaveExpansion.value,
                  colorIntensity: _colorIntensity.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // MASSIVE PARTICLE EXPLOSION SYSTEM
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: UltraCosmicParticlePainter(
                  particles: _particles,
                  progress: _particleSpread.value,
                  explosionRadius: _explosionRadius.value,
                  colorIntensity: _colorIntensity.value,
                  chaosIntensity: _chaosIntensity.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // COLOR WAVE SYSTEM
          AnimatedBuilder(
            animation: _colorExplosionController,
            builder: (context, child) {
              return CustomPaint(
                painter: ColorWavePainter(
                  waves: _colorWaves,
                  progress: _colorIntensity.value,
                  time: _particleController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // ENERGY BURST SYSTEM
          AnimatedBuilder(
            animation: _explosionController,
            builder: (context, child) {
              return CustomPaint(
                painter: EnergyBurstPainter(
                  bursts: _energyBursts,
                  progress: _explosionRadius.value,
                  intensity: _colorIntensity.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // INITIAL SINGULARITY (super intense white point)
          Center(
            child: AnimatedBuilder(
              animation: _bigBangController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bigBangScale.value,
                  child: Container(
                    width: 2,
                    height: 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.9),
                          blurRadius: 20,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.8),
                          blurRadius: 40,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // MAIN EXPLOSION BURST
          Center(
            child: AnimatedBuilder(
              animation: _explosionController,
              builder: (context, child) {
                if (_explosionController.value == 0) return const SizedBox();

                return Transform.scale(
                  scale: _explosionRadius.value,
                  child: Container(
                    width: 400, // Bigger explosion
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.yellow.withOpacity(0.9),
                          Colors.orange.withOpacity(0.8),
                          Colors.red.withOpacity(0.7),
                          Colors.purple.withOpacity(0.5),
                          Colors.blue.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.1, 0.2, 0.3, 0.5, 0.7, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // MULTIPLE COLOR WAVE EXPLOSIONS
          AnimatedBuilder(
            animation: _colorExplosionController,
            builder: (context, child) {
              return Stack(
                children: List.generate(12, (index) { // More waves
                  final delay = index * 0.08;
                  final adjustedProgress = math.max(0.0, _colorIntensity.value - delay);

                  return Center(
                    child: Transform.scale(
                      scale: adjustedProgress * 4.0, // Bigger scale
                      child: Container(
                        width: 200 + (index * 40),
                        height: 200 + (index * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getCosmicColor(math.Random(index)).withOpacity(
                              adjustedProgress * 0.4,
                            ),
                            width: 4 + (index % 3), // Varying thickness
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          // ULTRA PSYCHEDELIC MINUTE MADNESS TEXT FORMATION
          Center(
            child: AnimatedBuilder(
              animation: _textFormationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: Transform.scale(
                    scale: _textScale.value,
                    child: Transform.rotate(
                      angle: (1 - _textScale.value) * 0.5, // Rotation during formation
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.red.withOpacity(_textOpacity.value),
                            Colors.orange.withOpacity(_textOpacity.value),
                            Colors.yellow.withOpacity(_textOpacity.value),
                            Colors.green.withOpacity(_textOpacity.value),
                            Colors.blue.withOpacity(_textOpacity.value),
                            Colors.indigo.withOpacity(_textOpacity.value),
                            Colors.purple.withOpacity(_textOpacity.value),
                            Colors.pink.withOpacity(_textOpacity.value),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          transform: GradientRotation(_particleController.value * 6.28),
                        ).createShader(bounds),
                        child: Text(
                          'MINUTE MADNESS',
                          style: GoogleFonts.creepster(
                            fontSize: 48, // Bigger text
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.9),
                                blurRadius: 15,
                                offset: const Offset(5, 5),
                              ),
                              Shadow(
                                color: Colors.white.withOpacity(_textOpacity.value * 0.8),
                                blurRadius: 25,
                                offset: const Offset(-4, -4),
                              ),
                              Shadow(
                                color: Colors.purple.withOpacity(_textOpacity.value * 0.6),
                                blurRadius: 35,
                                offset: const Offset(0, 0),
                              ),
                              Shadow(
                                color: Colors.cyan.withOpacity(_textOpacity.value * 0.4),
                                blurRadius: 45,
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

// Enhanced particle data class
class CosmicParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double depth;

  CosmicParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.depth,
  });
}

// Color wave data class
class ColorWave {
  final double startAngle;
  final double speed;
  final double width;
  final Color color;
  final double intensity;

  ColorWave({
    required this.startAngle,
    required this.speed,
    required this.width,
    required this.color,
    required this.intensity,
  });
}

// Energy burst data class
class EnergyBurst {
  final double angle;
  final double length;
  final double thickness;
  final Color color;
  final double delay;

  EnergyBurst({
    required this.angle,
    required this.length,
    required this.thickness,
    required this.color,
    required this.delay,
  });
}

// Ultra enhanced cosmic particle painter
class UltraCosmicParticlePainter extends CustomPainter {
  final List<CosmicParticle> particles;
  final double progress;
  final double explosionRadius;
  final double colorIntensity;
  final double chaosIntensity;

  UltraCosmicParticlePainter({
    required this.particles,
    required this.progress,
    required this.explosionRadius,
    required this.colorIntensity,
    required this.chaosIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = math.max(size.width, size.height);

    // Sort particles by depth for proper layering
    final sortedParticles = List<CosmicParticle>.from(particles)
      ..sort((a, b) => a.depth.compareTo(b.depth));

    for (final particle in sortedParticles) {
      final distance = progress * particle.speed * maxDistance * 1.2;

      // Add chaos displacement
      final chaosX = math.sin(progress * 10 + particle.angle * 3) * chaosIntensity * 50;
      final chaosY = math.cos(progress * 8 + particle.angle * 2) * chaosIntensity * 50;

      final x = center.dx + math.cos(particle.angle) * distance + chaosX;
      final y = center.dy + math.sin(particle.angle) * distance + chaosY;

      // Enhanced fade with depth
      final opacity = math.max(0.0, (1.0 - progress * 1.5) * (0.5 + particle.depth * 0.5));
      final sizeMultiplier = 1.0 + explosionRadius * 0.3;

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity * colorIntensity)
        ..style = PaintingStyle.fill;

      // Multi-layer glow effect
      final glowPaint1 = Paint()
        ..color = particle.color.withOpacity(opacity * colorIntensity * 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final glowPaint2 = Paint()
        ..color = particle.color.withOpacity(opacity * colorIntensity * 0.2)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      final particleSize = particle.size * sizeMultiplier;

      // Draw multiple glow layers
      canvas.drawCircle(Offset(x, y), particleSize * 3, glowPaint2);
      canvas.drawCircle(Offset(x, y), particleSize * 2, glowPaint1);
      canvas.drawCircle(Offset(x, y), particleSize, paint);

      // Add sparkle effect for some particles
      if (particle.depth > 0.8 && opacity > 0.3) {
        final sparklePaint = Paint()
          ..color = Colors.white.withOpacity(opacity * 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), particleSize * 0.3, sparklePaint);
      }
    }
  }

  @override
  bool shouldRepaint(UltraCosmicParticlePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.explosionRadius != explosionRadius ||
        oldDelegate.colorIntensity != colorIntensity ||
        oldDelegate.chaosIntensity != chaosIntensity;
  }
}

// Color wave painter
class ColorWavePainter extends CustomPainter {
  final List<ColorWave> waves;
  final double progress;
  final double time;

  ColorWavePainter({
    required this.waves,
    required this.progress,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height);

    for (final wave in waves) {
      final waveProgress = math.max(0.0, progress - wave.startAngle / (2 * math.pi));
      if (waveProgress <= 0) continue;

      final radius = waveProgress * maxRadius * wave.speed;
      final opacity = math.max(0.0, (1.0 - waveProgress) * wave.intensity);

      final paint = Paint()
        ..color = wave.color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = wave.width * (1.0 + math.sin(time * 5) * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, wave.width * 0.5);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(ColorWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.time != time;
  }
}

// Energy burst painter
class EnergyBurstPainter extends CustomPainter {
  final List<EnergyBurst> bursts;
  final double progress;
  final double intensity;

  EnergyBurstPainter({
    required this.bursts,
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final burst in bursts) {
      final burstProgress = math.max(0.0, progress - burst.delay);
      if (burstProgress <= 0) continue;

      final length = burstProgress * burst.length;
      final opacity = math.max(0.0, (1.0 - burstProgress) * intensity);

      final endX = center.dx + math.cos(burst.angle) * length;
      final endY = center.dy + math.sin(burst.angle) * length;

      final paint = Paint()
        ..color = burst.color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = burst.thickness
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, burst.thickness * 0.5);

      canvas.drawLine(center, Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(EnergyBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.intensity != intensity;
  }
}

// Shockwave painter
class ShockwavePainter extends CustomPainter {
  final double expansion;
  final double colorIntensity;

  ShockwavePainter({
    required this.expansion,
    required this.colorIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height);

    // Multiple shockwave rings
    for (int i = 0; i < 5; i++) {
      final delay = i * 0.1;
      final waveProgress = math.max(0.0, expansion - delay);
      if (waveProgress <= 0) continue;

      final radius = waveProgress * maxRadius * 2;
      final opacity = math.max(0.0, (1.0 - waveProgress) * colorIntensity * 0.6);

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (8 - i).toDouble()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (10 + i * 2).toDouble());

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(ShockwavePainter oldDelegate) {
    return oldDelegate.expansion != expansion || oldDelegate.colorIntensity != colorIntensity;
  }
}

// Chaos painter for random effects
class ChaosPainter extends CustomPainter {
  final double chaosIntensity;
  final double time;

  ChaosPainter({
    required this.chaosIntensity,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chaosIntensity <= 0) return;

    final random = math.Random(42); // Fixed seed for consistent chaos
    final center = Offset(size.width / 2, size.height / 2);

    // Random energy bolts
    for (int i = 0; i < 50; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final length = random.nextDouble() * 200 * chaosIntensity;
      final thickness = 1 + random.nextDouble() * 4;

      final startRadius = random.nextDouble() * 100;
      final startX = center.dx + math.cos(angle) * startRadius;
      final startY = center.dy + math.sin(angle) * startRadius;

      final endX = startX + math.cos(angle + math.sin(time * 5 + i) * 0.5) * length;
      final endY = startY + math.sin(angle + math.cos(time * 3 + i) * 0.5) * length;

      final opacity = chaosIntensity * (0.3 + math.sin(time * 10 + i) * 0.3);

      final paint = Paint()
        ..color = Color.lerp(
          Colors.purple,
          Colors.cyan,
          math.sin(time * 2 + i) * 0.5 + 0.5,
        )!.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }

    // Chaotic swirls
    for (int i = 0; i < 20; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final radius = 50 + random.nextDouble() * 150;
      final swirl = time * 2 + i;

      final centerX = center.dx + math.cos(angle) * radius * chaosIntensity;
      final centerY = center.dy + math.sin(angle) * radius * chaosIntensity;

      final swirlRadius = 20 + random.nextDouble() * 40;
      final opacity = chaosIntensity * 0.4;

      final paint = Paint()
        ..color = Color.lerp(
          Colors.orange,
          Colors.pink,
          math.sin(swirl) * 0.5 + 0.5,
        )!.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      final path = Path();
      for (double t = 0; t < 2 * math.pi; t += 0.1) {
        final x = centerX + math.cos(t + swirl) * swirlRadius * (1 + math.sin(t * 3) * 0.3);
        final y = centerY + math.sin(t + swirl) * swirlRadius * (1 + math.cos(t * 2) * 0.3);
        if (t == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ChaosPainter oldDelegate) {
    return oldDelegate.chaosIntensity != chaosIntensity || oldDelegate.time != time;
  }
}