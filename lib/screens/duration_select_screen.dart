// lib/screens/duration_select_screen.dart - UPDATED WITH MEMORY-STYLE BUTTONS
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tournament_screen.dart';
import 'lobby_screen.dart';
import '../screens/tournament_setup_screen.dart';
import '../main.dart' show targetDuration, psychedelicPalette, backgroundSwapDuration;
import 'precision_tap_screen.dart';
import 'game_selection_screen.dart';  // Add this import

class DurationSelectScreen extends StatefulWidget {
  const DurationSelectScreen({super.key});
  @override
  State<DurationSelectScreen> createState() => _DurationSelectScreenState();
}

class _DurationSelectScreenState extends State<DurationSelectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<Color> _currentColors;
  late List<Color> _nextColors;

  @override
  void initState() {
    super.initState();
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // FASTER transitions like main screen
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _ctrl.forward(from: 0);
      }
    })..forward();
  }

  List<Color> _generateGradient() {
    final random = Random();
    // INTENSIFIED: More vibrant, saturated colors to match main screen
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
        5, (_) => vibrantColors[random.nextInt(vibrantColors.length)]); // More colors
  }

  @override
  void dispose() {
    _ctrl.dispose();
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

          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: interpolatedColors,
                center: Alignment.center,
                radius: 1.2,
                stops: [0.0, 0.3, 0.6, 0.8, 1.0], // More dramatic color transitions
              ),
            ),
            // ADDED: Secondary animated overlay for more chaos like main screen
            child: AnimatedBuilder(
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
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      transform: GradientRotation(_ctrl.value * 6.28), // Rotating overlay
                    ),
                  ),
                  child: child,
                );
              },
              child: SafeArea(
                child: Stack(
                  children: [
                    // Back button with psychedelic styling
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
                          onPressed: () {
                            // Always go back to game selection screen
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const GameSelectionScreen()),
                                  (route) => false,  // Remove all previous routes
                            );
                          },
                        ),
                      ),
                    ),

                    // Main content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // CRISP RAINBOW TITLE - READABLE!
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
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
                            ).createShader(bounds),
                            child: Text(
                              'MINUTE MADNESS',
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

                          const SizedBox(height: 20),

                          Text(
                            'Hit the Perfect 3-Second Mark',
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

                          const SizedBox(height: 50),

                          // UPDATED: Memory-style mode buttons
                          Column(
                            children: [
                              _PsychedelicModeCard(
                                title: 'Practice Mode',
                                subtitle: 'Perfect your timing skills',
                                description: 'Train your precision without pressure',
                                icon: Icons.timer,
                                isPractice: true,
                                animationController: _ctrl,
                                colors: interpolatedColors,
                              ),

                              const SizedBox(height: 28),

                              _PsychedelicModeCard(
                                title: 'Tournament Mode',
                                subtitle: '64 players, elimination rounds',
                                description: 'Compete for the ultimate timing crown',
                                icon: Icons.emoji_events,
                                isPractice: false,
                                animationController: _ctrl,
                                colors: interpolatedColors,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LobbyScreen()),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // PSYCHEDELIC GAME RULES (similar to memory)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: RadialGradient(
                                colors: interpolatedColors.map((c) => c.withOpacity(0.3)).toList(),
                                center: Alignment.center,
                                radius: 1.0,
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
                                Text(
                                  'How to Play:',
                                  style: GoogleFonts.chicle(
                                    fontSize: 18,
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
                                const SizedBox(height: 12),
                                Text(
                                  '• Press START to begin timing\n'
                                      '• Press STOP at exactly 3.000 seconds\n'
                                      '• Closest to perfect time advances\n'
                                      '• Tournament: 64 → 32 → 16 → 8 → 4 → 2 → 1\n'
                                      '• Last player standing wins!',
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
                                  textAlign: TextAlign.left,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// NEW: Memory-style card component
class _PsychedelicModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final bool isPractice;
  final VoidCallback? onTap;
  final AnimationController animationController;
  final List<Color> colors;

  const _PsychedelicModeCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.isPractice,
    required this.animationController,
    required this.colors,
    this.onTap,
  });

  @override
  State<_PsychedelicModeCard> createState() => _PsychedelicModeCardState();
}

class _PsychedelicModeCardState extends State<_PsychedelicModeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _cardAnimController;
  late List<Color> _cardColors;
  late List<Color> _nextCardColors;

  @override
  void initState() {
    super.initState();

    _cardColors = _generateCardGradient();
    _nextCardColors = _generateCardGradient();

    _cardAnimController = AnimationController(
      duration: const Duration(seconds: 3), // Slower than background for variation
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cardColors = List.from(_nextCardColors);
        _nextCardColors = _generateCardGradient();
        _cardAnimController.forward(from: 0);
      }
    })..forward();
  }

  List<Color> _generateCardGradient() {
    final random = Random();
    // Same vibrant colors as the background!
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
        4, (_) => vibrantColors[random.nextInt(vibrantColors.length)]);
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cardAnimController,
      builder: (context, child) {
        final t = _cardAnimController.value;
        final interpolatedColors = <Color>[];

        for (int i = 0; i < _cardColors.length; i++) {
          interpolatedColors.add(
              Color.lerp(_cardColors[i], _nextCardColors[i], t) ?? _cardColors[i]
          );
        }

        return GestureDetector(
          onTap: widget.onTap ?? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrecisionTapScreen(
                  target: targetDuration,
                  tourneyId: 'practice_mode',
                  round: 1,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              // PSYCHEDELIC BOX BACKGROUND!
              gradient: RadialGradient(
                colors: interpolatedColors.map((c) => c.withOpacity(0.85)).toList(),
                center: Alignment.center,
                radius: 1.0,
                stops: [0.0, 0.4, 0.7, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: interpolatedColors[0].withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: interpolatedColors[2].withOpacity(0.2),
                  blurRadius: 25,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Row(
              children: [
                // GRADIENT CIRCLE WITH ICON (like memory style)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        interpolatedColors[0].withOpacity(0.7),
                        interpolatedColors[1].withOpacity(0.5),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
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
                      Text(
                        widget.subtitle,
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
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}