// lib/screens/game_selection_screen.dart - WITH RAINBOW TEXT
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import 'duration_select_screen.dart';
import 'memory_select_screen.dart';
import 'match_select_screen.dart';
import 'momentum_select_screen.dart';

class GameSelectionScreen extends StatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen>
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
      duration: const Duration(seconds: 2), // FASTER transitions for more intensity
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
    // INTENSIFIED: More vibrant, saturated colors to match the MINUTE MADNESS energy
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
        5, (_) => vibrantColors[random.nextInt(vibrantColors.length)]); // More colors for complexity
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
              // ADDED: Overlay pattern for extra intensity
            ),
            // ADDED: Secondary animated overlay for more chaos
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // CRISP RAINBOW TITLE - READABLE AND BOLD!
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

                      const SizedBox(height: 40),

                      // Clean game options with psychedelic boxes
                      Column(
                        children: [
                          // Game mode buttons
                          _GameModeCard(
                            title: 'MINUTE MADNESS',
                            subtitle: 'Precision Timing Challenge',
                            description: 'Hit the exact 3-second mark',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DurationSelectScreen()),
                            ),
                          ),

                          const SizedBox(height: 20),

                          _GameModeCard(
                            title: 'MEMORY MADNESS',
                            subtitle: 'Pattern Memory Challenge',
                            description: 'Remember increasingly complex sequences',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MemorySelectScreen()),
                            ),
                          ),

                          const SizedBox(height: 20),

                          _GameModeCard(
                            title: 'MATCH MADNESS',
                            subtitle: 'Speed Matching Challenge',
                            description: 'Match psychedelic tarot cards at lightning speed',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MatchSelectScreen()),
                            ),
                            isComingSoon: false,
                          ),

                          const SizedBox(height: 20),

                          _GameModeCard(
                            title: 'MOMENTUM MADNESS',
                            subtitle: 'Momentum Building Challenge',
                            description: 'Spin a wheel as it gets progressively faster',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MomentumSelectScreen()),
                            ),
                            isComingSoon: false,
                          ),

                          const SizedBox(height: 20),

                          _GameModeCard(
                            title: 'MORE COMING SOON',
                            subtitle: 'New Challenges',
                            description: 'Even more exciting tournaments',
                            onTap: () => _showComingSoon(context, 'Future Games'),
                            isComingSoon: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showComingSoon(BuildContext context, String gameName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.purple.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Coming Soon!',
          style: GoogleFonts.chicle(
            fontSize: 20,
            color: Colors.yellow,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '$gameName is currently in development.\n\nStay tuned for epic tournaments!',
          style: GoogleFonts.chicle(
            fontSize: 16,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Got it!',
              style: GoogleFonts.chicle(color: Colors.cyan),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;
  final bool isComingSoon;

  const _GameModeCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  State<_GameModeCard> createState() => _GameModeCardState();
}

class _GameModeCardState extends State<_GameModeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<Color> _cardColors;
  late List<Color> _nextCardColors;

  @override
  void initState() {
    super.initState();

    _cardColors = _generateCardGradient();
    _nextCardColors = _generateCardGradient();

    _animController = AnimationController(
      duration: const Duration(seconds: 3), // Slower than background for variation
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cardColors = List.from(_nextCardColors);
        _nextCardColors = _generateCardGradient();
        _animController.forward(from: 0);
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
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final t = _animController.value;
        final interpolatedColors = <Color>[];

        for (int i = 0; i < _cardColors.length; i++) {
          interpolatedColors.add(
              Color.lerp(_cardColors[i], _nextCardColors[i], t) ?? _cardColors[i]
          );
        }

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              // PSYCHEDELIC BOX BACKGROUND!
              gradient: widget.isComingSoon
                  ? LinearGradient(
                colors: [
                  Colors.grey.shade600.withOpacity(0.7),
                  Colors.grey.shade700.withOpacity(0.5),
                  Colors.grey.shade800.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : RadialGradient(
                colors: interpolatedColors.map((c) => c.withOpacity(0.85)).toList(),
                center: Alignment.center,
                radius: 1.0,
                stops: [0.0, 0.4, 0.7, 1.0],
              ),
              border: Border.all(
                color: widget.isComingSoon
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                if (!widget.isComingSoon) ...[
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
                ] else ...[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // REPLACED EMOJI WITH GRADIENT CIRCLE AND ICON
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.isComingSoon
                            ? LinearGradient(
                          colors: [
                            Colors.grey.withOpacity(0.6),
                            Colors.grey.shade700.withOpacity(0.4),
                          ],
                        )
                            : RadialGradient(
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
                        _getIconForTitle(widget.title),
                        size: 24,
                        color: widget.isComingSoon ? Colors.white54 : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // RAINBOW TITLE FOR EACH GAME MODE
                          widget.title.contains('MADNESS') && !widget.isComingSoon
                              ? ShaderMask(
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
                            blendMode: BlendMode.srcIn,
                            child: Text(
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
                          )
                              : Text(
                            widget.title,
                            style: GoogleFonts.chicle(
                              fontSize: 20,
                              color: widget.isComingSoon ? Colors.white54 : Colors.white,
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
                              color: widget.isComingSoon ? Colors.white38 : Colors.white.withOpacity(0.9),
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
                    if (widget.isComingSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'SOON',
                          style: GoogleFonts.chicle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.description,
                  style: GoogleFonts.chicle(
                    fontSize: 14,
                    color: widget.isComingSoon ? Colors.white38 : Colors.white.withOpacity(0.95),
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to get appropriate icon based on title
  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'minute madness':
        return Icons.timer;
      case 'memory madness':
        return Icons.psychology;
      case 'match madness':
        return Icons.gps_fixed; // Use gps_fixed instead of target
      case 'momentum madness':
        return Icons.rotate_right;
      default:
        return Icons.games;
    }
  }
}