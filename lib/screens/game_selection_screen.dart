// lib/screens/game_selection_screen.dart - WITH ULTIMATE TOURNAMENT OF TOURNAMENTS
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import 'duration_select_screen.dart';
import 'memory_select_screen.dart';
import 'match_select_screen.dart';
import 'momentum_select_screen.dart';
import 'maze_select_screen.dart';
import 'ultimate_tournament_lobby_screen.dart'; // ADDED: Import Ultimate Tournament

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
                child: SingleChildScrollView(  // ADDED: ScrollView for overflow protection
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40), // ADDED: Top padding

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

                        // THE ULTIMATE TOURNAMENT - TOP BILLING!
                        _GameModeCard(
                          title: 'ULTIMATE TOURNAMENT',
                          subtitle: 'Tournament of Tournaments',
                          description: 'Compete in ALL 5 games in randomized order! Be crowned the Ultimate Champion across all challenges!',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UltimateTournamentLobbyScreen()),
                          ),
                          isUltimate: true, // SPECIAL FLAG for ultimate styling
                        ),

                        const SizedBox(height: 30),

                        // Section header for individual games
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'OR PLAY INDIVIDUAL GAMES:',
                            style: GoogleFonts.chicle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Individual game mode buttons
                        Column(
                          children: [
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
                            ),

                            const SizedBox(height: 20),

                            _GameModeCard(
                              title: 'MAZE MADNESS',
                              subtitle: 'Memory Navigation Challenge',
                              description: 'Navigate psychedelic mazes from memory alone',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MazeSelectScreen()),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40), // ADDED: Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
  final bool isUltimate; // ADDED: Special flag for Ultimate Tournament

  const _GameModeCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
    this.isComingSoon = false,
    this.isUltimate = false, // ADDED: Default false
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
      duration: Duration(
        milliseconds: widget.isUltimate ? 1500 : 3000, // FASTER for Ultimate Tournament
      ),
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

    if (widget.isUltimate) {
      // ULTIMATE TOURNAMENT gets ALL the colors!
      final ultimateColors = [
        Colors.red.shade800,      // Precision
        Colors.orange.shade700,   // Momentum
        Colors.purple.shade800,   // Memory
        Colors.pink.shade700,     // Match
        Colors.blue.shade800,     // Maze
        Colors.amber.shade600,     // Champion
        Colors.cyan.shade600,
        Colors.green.shade700,
        Colors.yellow.shade600,
      ];
      return List.generate(
          6, (_) => ultimateColors[random.nextInt(ultimateColors.length)]);
    } else {
      // Regular games get standard vibrant colors
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
            padding: EdgeInsets.all(widget.isUltimate ? 25 : 20), // BIGGER padding for Ultimate
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.isUltimate ? 30 : 25), // More rounded for Ultimate
              // ULTIMATE TOURNAMENT gets special gradient!
              gradient: widget.isUltimate
                  ? RadialGradient(
                colors: [
                  interpolatedColors[0].withOpacity(0.95),
                  interpolatedColors[2].withOpacity(0.9),
                  interpolatedColors[4].withOpacity(0.85),
                  interpolatedColors[1].withOpacity(0.8),
                  interpolatedColors[3].withOpacity(0.75),
                  interpolatedColors[5].withOpacity(0.7),
                ],
                center: Alignment.center,
                radius: 1.2,
                stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              )
                  : RadialGradient(
                colors: interpolatedColors.map((c) => c.withOpacity(0.85)).toList(),
                center: Alignment.center,
                radius: 1.0,
                stops: [0.0, 0.4, 0.7, 1.0],
              ),
              border: Border.all(
                color: widget.isUltimate
                    ? Colors.white.withOpacity(0.9)  // BRIGHTER border for Ultimate
                    : Colors.white.withOpacity(0.6),
                width: widget.isUltimate ? 4 : 2,   // THICKER border for Ultimate
              ),
              boxShadow: widget.isUltimate ? [
                // ULTIMATE gets MEGA glow!
                BoxShadow(
                  color: Colors.white.withOpacity(0.6),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: interpolatedColors[0].withOpacity(0.8),
                  blurRadius: 40,
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: interpolatedColors[2].withOpacity(0.6),
                  blurRadius: 50,
                  spreadRadius: 4,
                ),
              ] : [
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
            child: Column(
              children: [
                Row(
                  children: [
                    // ULTIMATE gets a special multi-colored icon!
                    Container(
                      width: widget.isUltimate ? 60 : 48,  // BIGGER for Ultimate
                      height: widget.isUltimate ? 60 : 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.isUltimate
                            ? SweepGradient(  // RAINBOW gradient for Ultimate!
                          colors: [
                            Colors.red,
                            Colors.orange,
                            Colors.yellow,
                            Colors.green,
                            Colors.blue,
                            Colors.indigo,
                            Colors.purple,
                            Colors.pink,
                            Colors.red,
                          ],
                          transform: GradientRotation(_animController.value * 6.28),
                        )
                            : RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.9),
                            interpolatedColors[0].withOpacity(0.7),
                            interpolatedColors[1].withOpacity(0.5),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: widget.isUltimate ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(widget.isUltimate ? 0.6 : 0.3),
                            blurRadius: widget.isUltimate ? 20 : 10,
                            spreadRadius: widget.isUltimate ? 4 : 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getIconForTitle(widget.title),
                        size: widget.isUltimate ? 32 : 24,  // BIGGER icon for Ultimate
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 3,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ULTIMATE TOURNAMENT gets MEGA rainbow title!
                          widget.isUltimate
                              ? ShaderMask(
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
                                Colors.amber,
                                Colors.cyan,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              transform: GradientRotation(_animController.value * 2.0),
                            ).createShader(bounds),
                            blendMode: BlendMode.srcIn,
                            child: Text(
                              widget.title,
                              style: GoogleFonts.chicle(
                                fontSize: 24,  // BIGGER text for Ultimate
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.9),
                                    blurRadius: 6,
                                    offset: const Offset(3, 3),
                                  ),
                                ],
                              ),
                            ),
                          )
                              : widget.title.contains('MADNESS')
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
                              fontSize: widget.isUltimate ? 16 : 14,  // BIGGER subtitle for Ultimate
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: widget.isUltimate ? FontWeight.bold : FontWeight.normal,
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

                    // ULTIMATE gets special crown badge!
                    if (widget.isUltimate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withOpacity(0.9),
                              Colors.yellow.withOpacity(0.8),
                              Colors.orange.withOpacity(0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ULTIMATE',
                              style: GoogleFonts.chicle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.description,
                  style: GoogleFonts.chicle(
                    fontSize: widget.isUltimate ? 16 : 14,  // BIGGER description for Ultimate
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: widget.isUltimate ? FontWeight.w600 : FontWeight.normal,
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
      case 'ultimate tournament':
        return Icons.emoji_events;  // Crown for Ultimate Tournament
      case 'minute madness':
        return Icons.timer;
      case 'memory madness':
        return Icons.psychology;
      case 'match madness':
        return Icons.gps_fixed;
      case 'momentum madness':
        return Icons.rotate_right;
      case 'maze madness':
        return Icons.explore;
      default:
        return Icons.games;
    }
  }
}