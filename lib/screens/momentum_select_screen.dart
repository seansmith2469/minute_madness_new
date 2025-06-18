// lib/screens/momentum_select_screen.dart - FIXED VERSION
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import 'momentum_game_screen.dart';
import 'momentum_lobby_screen.dart';

class MomentumSelectScreen extends StatefulWidget {
  const MomentumSelectScreen({super.key});
  @override
  State<MomentumSelectScreen> createState() => _MomentumSelectScreenState();
}

// FIXED: Changed from SingleTickerProviderStateMixin to TickerProviderStateMixin
class _MomentumSelectScreenState extends State<MomentumSelectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _tutorialController;
  late final AnimationController _achievementController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  bool _showTutorial = false;
  int _tutorialStep = 0;
  List<TutorialParticle> _tutorialParticles = [];

  // Sample achievements to display (would normally come from storage)
  final List<String> _sampleAchievements = [
    'Perfect Shot Master',
    'Momentum Builder',
    'Comeback King'
  ];

  @override
  void initState() {
    super.initState();
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _ctrl.forward(from: 0);
      }
    })..forward();

    _tutorialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _achievementController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  List<Color> _generateGradient() {
    final random = Random();
    final vibrantColors = [
      Colors.red.shade700,
      Colors.orange.shade600,
      Colors.yellow.shade500,
      Colors.green.shade600,
      Colors.blue.shade700,
      Colors.indigo.shade600,
      Colors.purple.shade700,
      Colors.pink.shade600,
      Colors.cyan.shade500,
      Colors.lime.shade600,
      Colors.deepOrange.shade700,
      Colors.deepPurple.shade700,
    ];

    return List.generate(
        6, (_) => vibrantColors[random.nextInt(vibrantColors.length)]);
  }

  void _showMomentumTutorial() {
    setState(() {
      _showTutorial = true;
      _tutorialStep = 0;
    });

    _createTutorialParticles();
    _tutorialController.forward();
    HapticFeedback.selectionClick();
  }

  void _createTutorialParticles() {
    final random = Random();
    _tutorialParticles.clear();

    for (int i = 0; i < 15; i++) {
      _tutorialParticles.add(TutorialParticle(
        x: 200 + random.nextDouble() * 100,
        y: 300 + random.nextDouble() * 100,
        dx: (random.nextDouble() - 0.5) * 2,
        dy: (random.nextDouble() - 0.5) * 2,
        color: [Colors.yellow, Colors.orange, Colors.cyan, Colors.purple][random.nextInt(4)],
        size: 4 + random.nextDouble() * 6,
        life: 1.0,
      ));
    }
  }

  void _nextTutorialStep() {
    if (_tutorialStep < 4) {
      setState(() {
        _tutorialStep++;
      });
      HapticFeedback.selectionClick();
      _createTutorialParticles();
      _tutorialController.forward(from: 0);
    } else {
      _closeTutorial();
    }
  }

  void _closeTutorial() {
    setState(() {
      _showTutorial = false;
      _tutorialStep = 0;
    });
    _tutorialController.reset();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tutorialController.dispose();
    _achievementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = _ctrl.value;
          final interpolatedColors = <Color>[];

          for (int i = 0; i < _currentColors.length; i++) {
            interpolatedColors.add(
                Color.lerp(_currentColors[i], _nextColors[i], t) ?? _currentColors[i]
            );
          }

          return Stack(
            children: [
              // ENHANCED PSYCHEDELIC BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 1.4,
                    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // ENHANCED ROTATING OVERLAY
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[1].withOpacity(0.3),
                          Colors.transparent,
                          interpolatedColors[3].withOpacity(0.2),
                          Colors.transparent,
                          interpolatedColors[5].withOpacity(0.1),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_ctrl.value * 6.28),
                      ),
                    ),
                  );
                },
              ),

              // TUTORIAL PARTICLES
              if (_tutorialParticles.isNotEmpty)
                AnimatedBuilder(
                  animation: _tutorialController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: TutorialParticlePainter(_tutorialParticles, _tutorialController.value),
                      size: Size.infinite,
                    );
                  },
                ),

              // MAIN CONTENT
              SafeArea(
                child: Stack(
                  children: [
                    // Back button
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),

                    // Tutorial button
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedBuilder(
                        animation: _achievementController,
                        builder: (context, child) {
                          final pulse = 1.0 + (_achievementController.value * 0.1);
                          return Transform.scale(
                            scale: pulse,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.cyan.withOpacity(0.8),
                                    Colors.blue.withOpacity(0.6),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyan.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.help_outline, color: Colors.white, size: 28),
                                onPressed: _showMomentumTutorial,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Main content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ENHANCED RAINBOW TITLE
                          AnimatedBuilder(
                            animation: _achievementController,
                            builder: (context, child) {
                              final titleScale = 1.0 + (_achievementController.value * 0.05);
                              return Transform.scale(
                                scale: titleScale,
                                child: ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      Colors.red,
                                      Colors.orange,
                                      Colors.yellow,
                                      Colors.green,
                                      Colors.blue,
                                      Colors.indigo,
                                      Colors.purple,
                                      Colors.pink,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    transform: GradientRotation(_ctrl.value * 2.0),
                                  ).createShader(bounds),
                                  child: Text(
                                    'MOMENTUM MADNESS',
                                    style: GoogleFonts.creepster(
                                      fontSize: 36,
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
                              );
                            },
                          ),

                          const SizedBox(height: 15),

                          // Enhanced subtitle with momentum theme
                          AnimatedBuilder(
                            animation: _achievementController,
                            builder: (context, child) {
                              final subtitleOpacity = 0.8 + (_achievementController.value * 0.2);
                              return Opacity(
                                opacity: subtitleOpacity,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withOpacity(0.3),
                                        Colors.purple.withOpacity(0.2),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Master the Momentum • Control the Chaos',
                                    style: GoogleFonts.chicle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.7),
                                          blurRadius: 8,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 40),

                          // ENHANCED MODE BUTTONS
                          Column(
                            children: [
                              _EnhancedModeButton(
                                label: 'Practice Mode',
                                description: 'Master momentum mechanics & unlock achievements',
                                icon: Icons.fitness_center,
                                isPractice: true,
                                animationController: _ctrl,
                                colors: interpolatedColors,
                                achievements: _sampleAchievements,
                              ),

                              const SizedBox(height: 28),

                              _EnhancedModeButton(
                                label: 'Tournament Mode',
                                description: '64 players • Momentum builds pressure • Winner takes all',
                                icon: Icons.emoji_events,
                                isPractice: false,
                                animationController: _ctrl,
                                colors: interpolatedColors,
                                achievements: _sampleAchievements,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const MomentumLobbyScreen()),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // ENHANCED GAME RULES with momentum focus
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: RadialGradient(
                                colors: interpolatedColors.map((c) => c.withOpacity(0.3)).toList(),
                                center: Alignment.center,
                                radius: 1.2,
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: interpolatedColors[0].withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [Colors.yellow, Colors.orange, Colors.red],
                                  ).createShader(bounds),
                                  child: Text(
                                    'Momentum Mastery Guide:',
                                    style: GoogleFonts.chicle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.8),
                                          blurRadius: 4,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),

                                // Enhanced rules with momentum focus
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildRuleItem(
                                      '🎯',
                                      'Stop the wheel in the TARGET zone for points',
                                      Colors.yellow,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildRuleItem(
                                      '⚡',
                                      'Better accuracy = Higher momentum = Faster wheel',
                                      Colors.orange,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildRuleItem(
                                      '🔄',
                                      'Poor spins reduce momentum but enable comebacks',
                                      Colors.cyan,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildRuleItem(
                                      '🏆',
                                      'Master momentum to unlock achievements',
                                      Colors.purple,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildRuleItem(
                                      '👑',
                                      'Tournament: Survive 6 rounds, defeat 63 players',
                                      Colors.amber,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 25),

                          // Momentum tip
                          AnimatedBuilder(
                            animation: _achievementController,
                            builder: (context, child) {
                              final tipOpacity = 0.6 + (_achievementController.value * 0.4);
                              return Opacity(
                                opacity: tipOpacity,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 30),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.purple.withOpacity(0.3),
                                        Colors.indigo.withOpacity(0.2),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.purple.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        color: Colors.yellow,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Pro Tip: Start slow, build momentum gradually for best results!',
                                          style: GoogleFonts.chicle(
                                            fontSize: 14,
                                            color: Colors.white.withOpacity(0.9),
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withOpacity(0.7),
                                                blurRadius: 3,
                                                offset: const Offset(1, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // TUTORIAL OVERLAY
              if (_showTutorial)
                _buildTutorialOverlay(interpolatedColors),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRuleItem(String emoji, String text, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accentColor.withOpacity(0.3), accentColor.withOpacity(0.1)],
            ),
            border: Border.all(color: accentColor.withOpacity(0.5), width: 1),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: GoogleFonts.chicle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.95),
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.7),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialOverlay(List<Color> colors) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: RadialGradient(
              colors: colors.map((c) => c.withOpacity(0.4)).toList(),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Momentum Tutorial',
                style: GoogleFonts.creepster(
                  fontSize: 24,
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _buildTutorialStep(),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_tutorialStep > 0)
                    _buildTutorialButton(
                      'Previous',
                      Colors.cyan,
                          () {
                        setState(() {
                          _tutorialStep--;
                        });
                        HapticFeedback.selectionClick();
                      },
                    ),

                  _buildTutorialButton(
                    _tutorialStep == 4 ? 'Got It!' : 'Next',
                    Colors.green,
                    _nextTutorialStep,
                  ),

                  _buildTutorialButton(
                    'Skip',
                    Colors.red,
                    _closeTutorial,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialStep() {
    switch (_tutorialStep) {
      case 0:
        return Column(
          children: [
            Icon(Icons.touch_app, size: 60, color: Colors.cyan),
            const SizedBox(height: 15),
            Text(
              'Tap the wheel to start spinning!\n\nTap again to stop at the perfect moment.',
              style: GoogleFonts.chicle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case 1:
        return Column(
          children: [
            Icon(Icons.speed, size: 60, color: Colors.yellow),
            const SizedBox(height: 15),
            Text(
              'MOMENTUM SYSTEM\n\nGood shots increase wheel speed\nPoor shots decrease wheel speed\n\nMomentum range: 0.5x to 5.0x',
              style: GoogleFonts.chicle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case 2:
        return Column(
          children: [
            Icon(Icons.trending_up, size: 60, color: Colors.green),
            const SizedBox(height: 15),
            Text(
              'COMEBACK MECHANICS\n\nImprove by 200+ points while momentum is low to get COMEBACK BONUS!\n\nTarget zone shrinks as momentum increases.',
              style: GoogleFonts.chicle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case 3:
        return Column(
          children: [
            Icon(Icons.emoji_events, size: 60, color: Colors.orange),
            const SizedBox(height: 15),
            Text(
              'ACHIEVEMENTS\n\n🎯 Perfect Shot Master\n⭐ Triple Perfect Streak\n🚀 Momentum Master (4.0x+)\n🔄 Comeback King\n📈 Consistency Champion',
              style: GoogleFonts.chicle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case 4:
        return Column(
          children: [
            Icon(Icons.psychology, size: 60, color: Colors.purple),
            const SizedBox(height: 15),
            Text(
              'STRATEGY TIPS\n\n• Start with consistent shots to build momentum\n• Don\'t panic at high momentum - stay focused\n• Use poor spins strategically for easier comebacks\n• Master the rhythm for perfect streaks',
              style: GoogleFonts.chicle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        );

      default:
        return Container();
    }
  }

  Widget _buildTutorialButton(String text, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          text,
          style: GoogleFonts.chicle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _EnhancedModeButton extends StatefulWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool isPractice;
  final VoidCallback? onTap;
  final AnimationController animationController;
  final List<Color> colors;
  final List<String> achievements;

  const _EnhancedModeButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.isPractice,
    required this.animationController,
    required this.colors,
    required this.achievements,
    this.onTap,
  });

  @override
  State<_EnhancedModeButton> createState() => _EnhancedModeButtonState();
}

class _EnhancedModeButtonState extends State<_EnhancedModeButton>
    with TickerProviderStateMixin {
  late AnimationController _buttonAnimController;
  late AnimationController _glowController;
  late List<Color> _buttonColors;
  late List<Color> _nextButtonColors;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _buttonColors = _generateButtonGradient();
    _nextButtonColors = _generateButtonGradient();

    _buttonAnimController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _buttonColors = List.from(_nextButtonColors);
        _nextButtonColors = _generateButtonGradient();
        _buttonAnimController.forward(from: 0);
      }
    })..forward();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  List<Color> _generateButtonGradient() {
    final random = Random();
    final vibrantColors = widget.isPractice
        ? [Colors.cyan.shade600, Colors.blue.shade700, Colors.indigo.shade600, Colors.purple.shade700]
        : [Colors.orange.shade600, Colors.red.shade700, Colors.pink.shade600, Colors.purple.shade700];

    return List.generate(
        4, (_) => vibrantColors[random.nextInt(vibrantColors.length)]);
  }

  @override
  void dispose() {
    _buttonAnimController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _buttonAnimController,
      builder: (context, child) {
        final t = _buttonAnimController.value;
        final interpolatedColors = <Color>[];

        for (int i = 0; i < _buttonColors.length; i++) {
          interpolatedColors.add(
              Color.lerp(_buttonColors[i], _nextButtonColors[i], t) ?? _buttonColors[i]
          );
        }

        return AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glow = 0.7 + (_glowController.value * 0.3);
            final scale = _isPressed ? 0.98 : 1.0;

            return Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTapDown: (_) {
                  setState(() => _isPressed = true);
                  HapticFeedback.lightImpact();
                },
                onTapUp: (_) {
                  setState(() => _isPressed = false);
                },
                onTapCancel: () {
                  setState(() => _isPressed = false);
                },
                onTap: widget.onTap ?? () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MomentumGameScreen(
                        isPractice: widget.isPractice,
                        tourneyId: widget.isPractice ? 'momentum_practice' : 'momentum_tournament',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: RadialGradient(
                      colors: interpolatedColors.map((c) => c.withOpacity(glow)).toList(),
                      center: Alignment.center,
                      radius: 1.2,
                      stops: [0.0, 0.3, 0.6, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: interpolatedColors[0].withOpacity(0.4),
                        blurRadius: 15 + (glow * 10),
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: interpolatedColors[2].withOpacity(0.3),
                        blurRadius: 25 + (glow * 15),
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Enhanced icon with momentum effects
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.9),
                              interpolatedColors[0].withOpacity(0.8),
                              interpolatedColors[1].withOpacity(0.6),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(glow * 0.5),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                            BoxShadow(
                              color: interpolatedColors[0].withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 18),

                      // Enhanced text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [Colors.white, interpolatedColors[2], Colors.white],
                              ).createShader(bounds),
                              child: Text(
                                widget.label,
                                style: GoogleFonts.chicle(
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.8),
                                      blurRadius: 4,
                                      offset: const Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.description,
                              style: GoogleFonts.chicle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 2,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),

                            // Achievement preview for practice mode
                            if (widget.isPractice && widget.achievements.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                children: widget.achievements.take(3).map((achievement) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 1),
                                  ),
                                  child: Text(
                                    '🏆',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Enhanced arrow with momentum pulse
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          final arrowScale = 1.0 + (_glowController.value * 0.2);
                          return Transform.scale(
                            scale: arrowScale,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white.withOpacity(0.8),
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class TutorialParticle {
  double x, y, dx, dy, size, life;
  Color color;

  TutorialParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.color,
    required this.size,
    required this.life,
  });
}

class TutorialParticlePainter extends CustomPainter {
  final List<TutorialParticle> particles;
  final double animation;

  TutorialParticlePainter(this.particles, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final currentLife = particle.life * (1 - animation);
      if (currentLife <= 0) continue;

      final paint = Paint()
        ..color = particle.color.withOpacity(currentLife * 0.8)
        ..style = PaintingStyle.fill;

      final currentX = particle.x + (particle.dx * animation * 50);
      final currentY = particle.y + (particle.dy * animation * 50);
      final currentSize = particle.size * currentLife;

      canvas.drawCircle(
        Offset(currentX, currentY),
        currentSize,
        paint,
      );

      // Add glow effect
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(currentLife * 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(currentX, currentY),
        currentSize * 2,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(TutorialParticlePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}