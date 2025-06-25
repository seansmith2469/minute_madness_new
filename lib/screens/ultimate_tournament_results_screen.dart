// lib/screens/ultimate_tournament_results_screen.dart - ULTIMATE CHAMPION REVEAL
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette;
import '../services/ultimate_tournament_service.dart';
import 'game_selection_screen.dart';

class UltimateTournamentResultsScreen extends StatefulWidget {
  final String tourneyId;

  const UltimateTournamentResultsScreen({
    super.key,
    required this.tourneyId,
  });

  @override
  State<UltimateTournamentResultsScreen> createState() => _UltimateTournamentResultsScreenState();
}

class _UltimateTournamentResultsScreenState extends State<UltimateTournamentResultsScreen>
    with TickerProviderStateMixin {
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _championController;
  late AnimationController _fireworksController;
  late AnimationController _leaderboardController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  // Results data
  bool _isLoading = true;
  List<Map<String, dynamic>> _rankings = [];
  int _playerRank = 0;
  bool _isChampion = false;
  Map<String, dynamic>? _championData;

  // Fireworks particles
  List<FireworkParticle> _fireworks = [];

  @override
  void initState() {
    super.initState();

    // Initialize ULTIMATE psychedelic background
    _currentColors = _generateUltimateGradient();
    _nextColors = _generateUltimateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // SUPER FAST for ultimate intensity
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateUltimateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _championController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fireworksController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _leaderboardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _loadResults();
  }

  List<Color> _generateUltimateGradient() {
    final random = math.Random();
    // ULTIMATE rainbow colors representing all 5 games
    final ultimateColors = [
      Colors.red.shade900,      // Precision
      Colors.orange.shade800,   // Momentum
      Colors.purple.shade900,   // Memory
      Colors.pink.shade800,     // Match
      Colors.blue.shade900,     // Maze
      Colors.amber.shade600,     // Champion
      Colors.cyan.shade700,
      Colors.green.shade800,
      Colors.indigo.shade800,
      Colors.amber.shade700,
    ];

    return List.generate(
        8, (_) => ultimateColors[random.nextInt(ultimateColors.length)]);
  }

  Future<void> _loadResults() async {
    try {
      print('🏆 Loading Ultimate Tournament results for ${widget.tourneyId}');

      // Wait a moment for all results to be processed
      await Future.delayed(const Duration(seconds: 2));

      // Get overall rankings
      _rankings = await UltimateTournamentService.calculateOverallRankings(widget.tourneyId);

      if (_rankings.isNotEmpty) {
        // Find player's rank
        _playerRank = _rankings.indexWhere((player) => player['playerId'] == _uid) + 1;

        // Check if player is champion
        _isChampion = _rankings.isNotEmpty && _rankings.first['playerId'] == _uid;

        if (_rankings.isNotEmpty) {
          _championData = _rankings.first;

          // Complete the tournament with the champion
          if (_championData != null) {
            await UltimateTournamentService.completeTournament(
              widget.tourneyId,
              _championData!['playerId'],
            );
          }
        }

        print('🏆 Player rank: $_playerRank/${_rankings.length}, Champion: $_isChampion');
      }

      setState(() {
        _isLoading = false;
      });

      // Start animations
      _leaderboardController.forward();

      if (_isChampion) {
        _championController.forward();
        _createFireworks();
      }

    } catch (e) {
      print('🏆 Error loading Ultimate Tournament results: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createFireworks() {
    final random = math.Random();
    _fireworks.clear();

    for (int i = 0; i < 50; i++) {
      _fireworks.add(FireworkParticle(
        x: random.nextDouble(),
        y: 0.7 + random.nextDouble() * 0.3,
        dx: (random.nextDouble() - 0.5) * 0.01,
        dy: -random.nextDouble() * 0.02,
        color: [
          Colors.amber,
          Colors.yellow,
          Colors.orange,
          Colors.red,
          Colors.purple,
          Colors.cyan,
          Colors.green,
        ][random.nextInt(7)],
        size: 2 + random.nextDouble() * 4,
        life: 1.0,
        gravity: 0.0005,
      ));
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulsController.dispose();
    _championController.dispose();
    _fireworksController.dispose();
    _leaderboardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          final t = _backgroundController.value;
          final interpolatedColors = <Color>[];

          for (int i = 0; i < _currentColors.length; i++) {
            interpolatedColors.add(
                Color.lerp(_currentColors[i], _nextColors[i], t) ?? _currentColors[i]
            );
          }

          return Stack(
            children: [
              // ULTIMATE PSYCHEDELIC BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: _isChampion ? 3.0 : 2.0, // BIGGER for champions
                    stops: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 1.0],
                  ),
                ),
              ),

              // CHAMPION FIREWORKS
              if (_isChampion && _fireworks.isNotEmpty)
                AnimatedBuilder(
                  animation: _fireworksController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: FireworksPainter(_fireworks, _fireworksController.value),
                      size: Size.infinite,
                    );
                  },
                ),

              // ROTATING OVERLAYS
              AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.6),
                          Colors.transparent,
                          interpolatedColors[5].withOpacity(0.5),
                          Colors.transparent,
                          interpolatedColors[7].withOpacity(0.4),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_backgroundController.value * 12.0), // ULTRA FAST
                      ),
                    ),
                  );
                },
              ),

              // MAIN CONTENT
              SafeArea(
                child: _isLoading ? _buildLoadingScreen() : _buildResultsScreen(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulsController,
            builder: (context, child) {
              final scale = 1.0 + (_pulsController.value * 0.4);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.amber.withOpacity(0.9),
                        Colors.orange.withOpacity(0.8),
                        Colors.red.withOpacity(0.6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 120,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 50),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.amber,
                Colors.orange,
                Colors.red,
                Colors.purple,
                Colors.blue,
                Colors.green,
                Colors.amber,
              ],
            ).createShader(bounds),
            child: Text(
              'CALCULATING ULTIMATE CHAMPION',
              style: GoogleFonts.creepster(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.9),
                    blurRadius: 20,
                    offset: const Offset(5, 5),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Analyzing performance across all 5 games...',
            style: GoogleFonts.chicle(
              fontSize: 18,
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
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ULTIMATE TOURNAMENT TITLE
          AnimatedBuilder(
            animation: _pulsController,
            builder: (context, child) {
              final titleScale = 1.0 + (_pulsController.value * (_isChampion ? 0.2 : 0.1));
              return Transform.scale(
                scale: titleScale,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: _isChampion ? [
                      Colors.amber,
                      Colors.yellow,
                      Colors.orange,
                      Colors.red,
                      Colors.amber,
                    ] : [
                      Colors.red,
                      Colors.orange,
                      Colors.yellow,
                      Colors.green,
                      Colors.blue,
                      Colors.purple,
                      Colors.red,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    transform: GradientRotation(_backgroundController.value * 4.0),
                  ).createShader(bounds),
                  child: Text(
                    'ULTIMATE TOURNAMENT',
                    style: GoogleFonts.creepster(
                      fontSize: 42,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.9),
                          blurRadius: 25,
                          offset: const Offset(6, 6),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          // CHAMPION REVEAL
          if (_isChampion) _buildChampionReveal(),

          // PLAYER RESULT
          if (!_isChampion && _playerRank > 0) _buildPlayerResult(),

          const SizedBox(height: 40),

          // LEADERBOARD
          _buildLeaderboard(),

          const SizedBox(height: 40),

          // RETURN BUTTON
          _buildReturnButton(),
        ],
      ),
    );
  }

  Widget _buildChampionReveal() {
    return AnimatedBuilder(
      animation: _championController,
      builder: (context, child) {
        final scale = 1.0 + (_championController.value * 0.5);
        final glow = 0.5 + (_championController.value * 1.0);

        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(40),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: RadialGradient(
                colors: [
                  Colors.amber.withOpacity(0.95),
                  Colors.yellow.withOpacity(0.9),
                  Colors.orange.withOpacity(0.8),
                  Colors.red.withOpacity(0.7),
                ],
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(glow),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
                BoxShadow(
                  color: Colors.amber.withOpacity(0.8),
                  blurRadius: 80,
                  spreadRadius: 15,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 100,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 10,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.yellow,
                      Colors.orange,
                      Colors.white,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    '🏆 ULTIMATE CHAMPION! 🏆',
                    style: GoogleFonts.creepster(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.9),
                          blurRadius: 15,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'You have conquered all 5 games and proven yourself as the ultimate warrior!\n\nYou are the master of:\n• Precision • Momentum • Memory • Matching • Mazes',
                  style: GoogleFonts.chicle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 6,
                        offset: const Offset(2, 2),
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

  Widget _buildPlayerResult() {
    return AnimatedBuilder(
      animation: _leaderboardController,
      builder: (context, child) {
        final scale = _leaderboardController.value;

        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(30),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: RadialGradient(
                colors: [
                  _getRankColor(_playerRank).withOpacity(0.8),
                  _getRankColor(_playerRank).withOpacity(0.6),
                  _getRankColor(_playerRank).withOpacity(0.4),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getRankColor(_playerRank).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'YOUR ULTIMATE RANK',
                  style: GoogleFonts.creepster(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  '#$_playerRank',
                  style: GoogleFonts.chicle(
                    fontSize: 64,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 10,
                        offset: const Offset(3, 3),
                      ),
                    ],
                  ),
                ),

                Text(
                  'out of ${_rankings.length} ultimate warriors',
                  style: GoogleFonts.chicle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  _getRankDescription(_playerRank),
                  style: GoogleFonts.chicle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
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

  Widget _buildLeaderboard() {
    return AnimatedBuilder(
      animation: _leaderboardController,
      builder: (context, child) {
        final slideValue = _leaderboardController.value;

        return Transform.translate(
          offset: Offset(0, (1 - slideValue) * 100),
          child: Opacity(
            opacity: slideValue,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.purple.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'ULTIMATE LEADERBOARD',
                    style: GoogleFonts.creepster(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Top 10 players
                  ...(_rankings.take(10).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final player = entry.value;
                    final isCurrentPlayer = player['playerId'] == _uid;
                    final rank = index + 1;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isCurrentPlayer
                            ? Colors.yellow.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: isCurrentPlayer
                            ? Border.all(color: Colors.yellow, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Rank
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _getRankColor(rank).withOpacity(0.9),
                                  _getRankColor(rank).withOpacity(0.6),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: GoogleFonts.chicle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 15),

                          // Player info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCurrentPlayer ? 'YOU' : 'Player ${rank.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.chicle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Total Score: ${player['totalScore']}',
                                  style: GoogleFonts.chicle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Crown for champion
                          if (rank == 1)
                            Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 30,
                            ),
                        ],
                      ),
                    );
                  }).toList()),

                  if (_rankings.length > 10) ...[
                    const SizedBox(height: 20),
                    Text(
                      '...and ${_rankings.length - 10} more warriors',
                      style: GoogleFonts.chicle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReturnButton() {
    return AnimatedBuilder(
      animation: _pulsController,
      builder: (context, child) {
        final scale = 1.0 + (_pulsController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
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
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const GameSelectionScreen()),
                      (route) => false,
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                'Return to Game Selection',
                style: GoogleFonts.chicle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey.shade300;
    if (rank == 3) return Colors.orange.shade700;
    if (rank <= 10) return Colors.purple;
    if (rank <= 20) return Colors.blue;
    return Colors.green;
  }

  String _getRankDescription(int rank) {
    if (rank == 1) return 'Ultimate Champion across all 5 games!';
    if (rank <= 3) return 'Elite performance! You\'re in the top 3!';
    if (rank <= 10) return 'Excellent! You\'re in the top 10!';
    if (rank <= 20) return 'Great job! You\'re in the top 20!';
    if (rank <= 32) return 'Good performance! You made it to the top half!';
    return 'You competed against the best! Well played!';
  }
}

// Firework particle for champion celebration
class FireworkParticle {
  double x, y, dx, dy, size, life, gravity;
  Color color;

  FireworkParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.color,
    required this.size,
    required this.life,
    required this.gravity,
  });
}

class FireworksPainter extends CustomPainter {
  final List<FireworkParticle> particles;
  final double animation;

  FireworksPainter(this.particles, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final currentLife = particle.life * (1 - animation);
      if (currentLife <= 0) continue;

      final currentX = (particle.x + particle.dx * animation * 100) * size.width;
      final currentY = (particle.y + particle.dy * animation * 100 + particle.gravity * animation * animation) * size.height;

      final paint = Paint()
        ..color = particle.color.withOpacity(currentLife)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(currentX, currentY),
        particle.size * currentLife,
        paint,
      );

      // Add glow effect for fireworks
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(currentLife * 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(currentX, currentY),
        particle.size * currentLife * 3,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(FireworksPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}