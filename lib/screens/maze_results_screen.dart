// lib/screens/maze_results_screen.dart - FIXED MAZE MADNESS SURVIVAL RESULTS
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import 'maze_lobby_screen.dart';
import 'maze_game_screen.dart';

class MazeResultsScreen extends StatefulWidget {
  final String survivalId;
  final int playerRound;
  final bool completed;
  final int completionTime;
  final int wrongMoves;
  final bool isPractice;

  const MazeResultsScreen({
    super.key,
    required this.survivalId,
    required this.playerRound,
    required this.completed,
    required this.completionTime,
    required this.wrongMoves,
    this.isPractice = false,
  });

  @override
  State<MazeResultsScreen> createState() => _MazeResultsScreenState();
}

class _MazeResultsScreenState extends State<MazeResultsScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // Results data
  List<Map<String, dynamic>> _allResults = [];
  Map<String, dynamic>? _playerResult;
  bool _isDataLoaded = false;
  bool _playerAdvanced = false;
  int _playersEliminated = 0;
  int _playersRemaining = 0;
  int _playerRank = 0;

  // Round management
  Timer? _nextRoundTimer;
  int _nextRoundCountdown = 0;
  bool _survivalComplete = false;

  // PSYCHEDELIC ANIMATION CONTROLLERS
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _celebrationController;
  late AnimationController _eliminationController;
  late AnimationController _victoryController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  @override
  void initState() {
    super.initState();

    // Initialize INTENSE psychedelic animations
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _eliminationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _victoryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    if (!widget.isPractice) {
      _loadResults();
    } else {
      _setupPracticeResults();
    }
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    final mazeColors = [
      Colors.purple.shade800,
      Colors.pink.shade600,
      Colors.indigo.shade700,
      Colors.blue.shade700,
      Colors.cyan.shade500,
      Colors.teal.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.red.shade700,
      Colors.deepPurple.shade700,
    ];

    return List.generate(
        6, (_) => mazeColors[random.nextInt(mazeColors.length)]);
  }

  void _setupPracticeResults() {
    setState(() {
      _isDataLoaded = true;
      _playerAdvanced = widget.completed;
      if (widget.completed) {
        _celebrationController.forward();
      } else {
        _eliminationController.forward();
      }
    });
  }

  Future<void> _loadResults() async {
    try {
      print('🧩 Loading all results for round ${widget.playerRound}');

      // Wait a moment for bot results to be submitted
      await Future.delayed(const Duration(seconds: 2));

      // Keep trying to load results until we have a reasonable number
      int attempts = 0;
      const maxAttempts = 10; // Try for up to 10 seconds

      while (attempts < maxAttempts) {
        final resultsSnap = await _db
            .collection('maze_survival')
            .doc(widget.survivalId)
            .collection('results')
            .where('round', isEqualTo: widget.playerRound) // FIXED: Filter by current round
            .get();

        _allResults = resultsSnap.docs.map((doc) {
          final data = doc.data();
          return {
            'uid': doc.id.split('_round_')[0], // Extract UID from document ID
            'completed': data['completed'] ?? false,
            'completionTimeMs': data['completionTimeMs'] ?? 999999,
            'wrongMoves': data['wrongMoves'] ?? 999,
            'round': data['round'] ?? 1,
            'isBot': data['isBot'] ?? false,
          };
        }).toList();

        print('🧩 Attempt ${attempts + 1}: Found ${_allResults.length} results for round ${widget.playerRound}');

        // If we have a reasonable number of results (at least 20), proceed
        if (_allResults.length >= 20) {
          break;
        }

        // Wait before trying again
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }

      // Ensure player result is included even if not found in database
      final playerResultExists = _allResults.any((result) => result['uid'] == _uid);
      if (!playerResultExists) {
        print('🧩 Adding player result manually');
        _allResults.add({
          'uid': _uid,
          'completed': widget.completed,
          'completionTimeMs': widget.completionTime,
          'wrongMoves': widget.wrongMoves,
          'round': widget.playerRound,
          'isBot': false,
        });
      }

      print('🧩 Final results loaded: ${_allResults.length} total for round ${widget.playerRound}');

      // Find player result
      _playerResult = _allResults.firstWhere(
            (result) => result['uid'] == _uid,
        orElse: () => {
          'uid': _uid,
          'completed': widget.completed,
          'completionTimeMs': widget.completionTime,
          'wrongMoves': widget.wrongMoves,
          'round': widget.playerRound,
          'isBot': false,
        },
      );

      // Calculate results
      _calculateSurvivalStatus();

      // Check if survival is complete
      await _checkSurvivalStatus();

      setState(() {
        _isDataLoaded = true;
      });

      // Trigger appropriate effects
      if (_survivalComplete && _playerAdvanced) {
        _victoryController.forward();
      } else if (_playerAdvanced) {
        _celebrationController.forward();
        if (!_survivalComplete) {
          _startNextRoundCountdown();
        }
      } else {
        _eliminationController.forward();
      }

    } catch (e) {
      print('Error loading maze results: $e');
      setState(() {
        _isDataLoaded = true;
      });
    }
  }

  // FIXED: Calculate survival status per round with proper tournament brackets and advancement logic
  void _calculateSurvivalStatus() {
    // Filter results for the current round only
    final currentRoundResults = _allResults.where((r) => r['round'] == widget.playerRound).toList();

    print('🧩 Found ${currentRoundResults.length} results for round ${widget.playerRound}');

    // If we don't have enough results, don't calculate rankings yet
    if (currentRoundResults.length < 10) {
      print('🧩 Not enough results yet, using placeholder values');
      _playerRank = 0;
      _playersRemaining = 0;
      _playersEliminated = 0;
      _playerAdvanced = widget.completed; // Base advancement on completion for now
      return;
    }

    // EXPLICIT TOURNAMENT ADVANCEMENT CRITERIA:
    // 1. Players who completed the maze advance
    // 2. Ranked by: Fewest wrong moves first, then fastest time
    // 3. Only top 50% advance to next round (64→32→16→8→4→2→1)

    currentRoundResults.sort((a, b) {
      final aCompleted = a['completed'] as bool;
      final bCompleted = b['completed'] as bool;

      // Failed players are automatically eliminated
      if (aCompleted && !bCompleted) return -1;
      if (!aCompleted && bCompleted) return 1;

      if (!aCompleted && !bCompleted) {
        // Both failed - rank by time survived (longer = better rank, but still eliminated)
        return (b['completionTimeMs'] as int).compareTo(a['completionTimeMs'] as int);
      }

      // Both completed - RANK BY: 1) Fewer mistakes, 2) Faster time
      final aWrongMoves = a['wrongMoves'] as int;
      final bWrongMoves = b['wrongMoves'] as int;

      if (aWrongMoves != bWrongMoves) {
        return aWrongMoves.compareTo(bWrongMoves); // Fewer mistakes = better rank
      }

      // Same mistakes - faster time wins
      return (a['completionTimeMs'] as int).compareTo(b['completionTimeMs'] as int);
    });

    // Find player rank in THIS round
    _playerRank = currentRoundResults.indexWhere((result) => result['uid'] == _uid) + 1;

    // Handle case where player not found in results
    if (_playerRank == 0) {
      print('🧩 Player not found in results, adding manually for ranking');
      currentRoundResults.add({
        'uid': _uid,
        'completed': widget.completed,
        'completionTimeMs': widget.completionTime,
        'wrongMoves': widget.wrongMoves,
        'round': widget.playerRound,
        'isBot': false,
      });

      // Re-sort with player included
      currentRoundResults.sort((a, b) {
        final aCompleted = a['completed'] as bool;
        final bCompleted = b['completed'] as bool;

        if (aCompleted && !bCompleted) return -1;
        if (!aCompleted && bCompleted) return 1;

        if (!aCompleted && !bCompleted) {
          return (b['completionTimeMs'] as int).compareTo(a['completionTimeMs'] as int);
        }

        final aWrongMoves = a['wrongMoves'] as int;
        final bWrongMoves = b['wrongMoves'] as int;

        if (aWrongMoves != bWrongMoves) {
          return aWrongMoves.compareTo(bWrongMoves);
        }

        return (a['completionTimeMs'] as int).compareTo(b['completionTimeMs'] as int);
      });

      _playerRank = currentRoundResults.indexWhere((result) => result['uid'] == _uid) + 1;
    }

    // Tournament bracket advancement logic
    final expectedPlayers = _getExpectedPlayersForRound(widget.playerRound);
    final advancingPlayers = _getAdvancingPlayersForRound(widget.playerRound);

    // Only players who completed AND are in top 50% advance
    final completedResults = currentRoundResults.where((r) => r['completed'] as bool).toList();
    final actualAdvancing = math.min(completedResults.length, advancingPlayers);

    _playersRemaining = actualAdvancing;
    _playersEliminated = currentRoundResults.length - actualAdvancing;

    // Player advances if they completed AND are ranked high enough
    _playerAdvanced = widget.completed && _playerRank <= advancingPlayers;

    print('🧩 Round ${widget.playerRound} bracket:');
    print('🧩 - Total players: ${currentRoundResults.length}');
    print('🧩 - Completed maze: ${completedResults.length}');
    print('🧩 - Advancing (top $advancingPlayers): $actualAdvancing');
    print('🧩 - Eliminated: $_playersEliminated');
    print('🧩 - Player rank: $_playerRank/${currentRoundResults.length}');
    print('🧩 - Player advanced: $_playerAdvanced');
  }

  // Helper method to get expected players for each round
  int _getExpectedPlayersForRound(int round) {
    switch (round) {
      case 1: return 64;  // Round 1: 64 players
      case 2: return 32;  // Round 2: 32 players
      case 3: return 16;  // Round 3: 16 players
      case 4: return 8;   // Round 4: 8 players
      case 5: return 4;   // Round 5: 4 players
      case 6: return 2;   // Round 6: 2 players
      default: return 64;
    }
  }

  // Helper method to get how many advance from each round
  int _getAdvancingPlayersForRound(int round) {
    switch (round) {
      case 1: return 32;  // Round 1: Top 32 advance
      case 2: return 16;  // Round 2: Top 16 advance
      case 3: return 8;   // Round 3: Top 8 advance
      case 4: return 4;   // Round 4: Top 4 advance
      case 5: return 2;   // Round 5: Top 2 advance
      case 6: return 1;   // Round 6: 1 winner
      default: return 32;
    }
  }

  // FIXED: Proper survival completion logic
  Future<void> _checkSurvivalStatus() async {
    try {
      final survivalDoc = await _db.collection('maze_survival').doc(widget.survivalId).get();
      final survivalData = survivalDoc.data();

      if (survivalData != null) {
        final currentRound = survivalData['round'] as int? ?? 1;

        // FIXED: Survival is only complete if we've finished ALL 6 rounds
        // AND there's 1 or fewer players remaining
        _survivalComplete = (currentRound >= 6 && _playersRemaining <= 1) ||
            (_playersRemaining <= 1 && currentRound > 1);

        print('🧩 Survival status check: Round $currentRound, $_playersRemaining remaining, Complete: $_survivalComplete');
      }
    } catch (e) {
      print('🧩 Error checking survival status: $e');
    }
  }

  // FIXED: Only start countdown if we haven't completed all rounds AND player advanced
  void _startNextRoundCountdown() {
    if (widget.playerRound >= 6) {
      print('🧩 All rounds completed, checking for final victory');
      return;
    }

    if (!_playerAdvanced) {
      print('🧩 Player eliminated, no next round');
      return;
    }

    _nextRoundCountdown = 5; // 5 second countdown
    _nextRoundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _nextRoundCountdown--;
      });

      if (_nextRoundCountdown <= 0) {
        timer.cancel();
        _navigateToNextRound();
      }
    });
  }

  // FIXED: Navigation logic
  void _navigateToNextRound() {
    final nextRound = widget.playerRound + 1;

    if (nextRound > 6) {
      print('🧩 No more rounds, staying on results');
      return;
    }

    print('🧩 Advancing to round $nextRound');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MazeGameScreen(
          isPractice: false,
          survivalId: widget.survivalId,
          round: nextRound,
        ),
      ),
    );
  }

  // Helper method for status text
  String _getStatusText() {
    if (_survivalComplete && _playerAdvanced) {
      return 'SURVIVAL CHAMPION!';
    } else if (_playerAdvanced && widget.playerRound < 6) {
      return 'Round ${widget.playerRound} Complete - Advancing to Round ${widget.playerRound + 1}';
    } else if (_playerAdvanced && widget.playerRound >= 6) {
      return 'Final Round Complete!';
    } else {
      return 'Eliminated in Round ${widget.playerRound}';
    }
  }

  @override
  void dispose() {
    _nextRoundTimer?.cancel();
    _backgroundController.dispose();
    _pulsController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    _celebrationController.dispose();
    _eliminationController.dispose();
    _victoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return _buildLoadingScreen();
    }

    if (_survivalComplete && _playerAdvanced) {
      return _buildVictoryScreen();
    } else if (_playerAdvanced) {
      return _buildAdvancementScreen();
    } else {
      return _buildEliminationScreen();
    }
  }

  Widget _buildLoadingScreen() {
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

          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: interpolatedColors,
                center: Alignment.center,
                radius: 2.0,
                stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.purple,
                                Colors.pink,
                                Colors.cyan,
                                Colors.blue,
                                Colors.purple,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.explore,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Analyzing maze performance...',
                    style: GoogleFonts.chicle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVictoryScreen() {
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
              // VICTORY BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.0,
                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // VICTORY EXPLOSION
              AnimatedBuilder(
                animation: _victoryController,
                builder: (context, child) {
                  final explosion = _victoryController.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.yellow.withOpacity(0.8 * (1 - explosion)),
                          Colors.orange.withOpacity(0.6 * (1 - explosion)),
                          Colors.red.withOpacity(0.4 * (1 - explosion)),
                          Colors.purple.withOpacity(0.2 * (1 - explosion)),
                          Colors.transparent,
                        ],
                        center: Alignment.center,
                        radius: explosion * 4.0,
                      ),
                    ),
                  );
                },
              ),

              // ROTATING VICTORY OVERLAY
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          Colors.yellow.withOpacity(0.3),
                          Colors.transparent,
                          Colors.orange.withOpacity(0.3),
                          Colors.transparent,
                          Colors.red.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        center: Alignment.center,
                        transform: GradientRotation(_rotationController.value * 6.28),
                      ),
                    ),
                  );
                },
              ),

              // MAIN CONTENT
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // VICTORY TITLE
                    AnimatedBuilder(
                      animation: _victoryController,
                      builder: (context, child) {
                        final bounce = math.sin(_victoryController.value * math.pi * 6) * 0.3;
                        final scale = 1.0 + bounce;

                        return Transform.scale(
                          scale: scale,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.yellow,
                                Colors.orange,
                                Colors.red,
                                Colors.purple,
                                Colors.cyan,
                                Colors.yellow,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              '🏆 MAZE CHAMPION! 🏆',
                              style: GoogleFonts.creepster(
                                fontSize: 42,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4.0,
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
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // VICTORY STATS
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulsController.value * 0.1);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: RadialGradient(
                                colors: [
                                  Colors.yellow.withOpacity(0.9),
                                  Colors.orange.withOpacity(0.7),
                                  Colors.red.withOpacity(0.5),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.yellow.withOpacity(0.6),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'LAST EXPLORER STANDING!',
                                  style: GoogleFonts.chicle(
                                    fontSize: 24,
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
                                const SizedBox(height: 15),
                                Text(
                                  'You survived all ${widget.playerRound} rounds\n'
                                      'and conquered the psychedelic maze!\n\n'
                                      'Your legendary navigation skills\n'
                                      'have earned you eternal glory!',
                                  style: GoogleFonts.chicle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.95),
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
                    ),

                    const SizedBox(height: 40),

                    // RETURN BUTTON
                    _buildReturnButton(interpolatedColors, 'New Challenge'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdvancementScreen() {
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
              // SUCCESS BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.0,
                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // SUCCESS CELEBRATION
              AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, child) {
                  final celebration = _celebrationController.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.green.withOpacity(0.8 * (1 - celebration)),
                          Colors.lime.withOpacity(0.6 * (1 - celebration)),
                          Colors.cyan.withOpacity(0.4 * (1 - celebration)),
                          Colors.transparent,
                        ],
                        center: Alignment.center,
                        radius: celebration * 3.0,
                      ),
                    ),
                  );
                },
              ),

              // MAIN CONTENT
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SUCCESS TITLE
                    AnimatedBuilder(
                      animation: _celebrationController,
                      builder: (context, child) {
                        final bounce = math.sin(_celebrationController.value * math.pi * 4) * 0.2;
                        final scale = 1.0 + bounce;

                        return Transform.scale(
                          scale: scale,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.green,
                                Colors.lime,
                                Colors.cyan,
                                Colors.blue,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              '🎯 MAZE CONQUERED! 🎯',
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
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // ROUND RESULTS
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulsController.value * 0.1);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: RadialGradient(
                                colors: [
                                  Colors.green.withOpacity(0.9),
                                  Colors.cyan.withOpacity(0.7),
                                  Colors.blue.withOpacity(0.5),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.6),
                                  blurRadius: 25,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Round ${widget.playerRound} Complete!',
                                  style: GoogleFonts.chicle(
                                    fontSize: 24,
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
                                const SizedBox(height: 15),
                                Text(
                                  'Time: ${(widget.completionTime / 1000).toStringAsFixed(2)}s\n'
                                      'Wrong Moves: ${widget.wrongMoves}\n'
                                      'Tournament Rank: #$_playerRank/${_getExpectedPlayersForRound(widget.playerRound)}',
                                  style: GoogleFonts.chicle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.95),
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
                                const SizedBox(height: 10),
                                Text(
                                  _playerAdvanced
                                      ? '🎉 ADVANCING TO ${widget.playerRound < 6 ? 'ROUND ${widget.playerRound + 1}' : 'VICTORY'}! 🎉\n'
                                      'Top ${_getAdvancingPlayersForRound(widget.playerRound)} advance (ranked by fewest mistakes, then speed)'
                                      : '❌ ELIMINATED ❌\n'
                                      'Only top ${_getAdvancingPlayersForRound(widget.playerRound)} advance to next round',
                                  style: GoogleFonts.chicle(
                                    fontSize: 14,
                                    color: _playerAdvanced ? Colors.green.shade200 : Colors.red.shade200,
                                    fontWeight: FontWeight.bold,
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
                    ),

                    const SizedBox(height: 30),

                    // NEXT ROUND COUNTDOWN
                    if (_nextRoundCountdown > 0 && !_survivalComplete) ...[
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulsController.value * 0.2);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.withOpacity(0.9),
                                    Colors.red.withOpacity(0.7),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.6),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Text(
                                'Next Round in $_nextRoundCountdown...',
                                style: GoogleFonts.creepster(
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
                          );
                        },
                      ),
                    ] else if (widget.isPractice) ...[
                      _buildReturnButton(interpolatedColors, 'Try Again'),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEliminationScreen() {
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
              // ELIMINATION BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors.map((c) =>
                    Color.lerp(c, Colors.red.shade900, 0.3) ?? c).toList(),
                    center: Alignment.center,
                    radius: 2.0,
                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // ELIMINATION EXPLOSION
              AnimatedBuilder(
                animation: _eliminationController,
                builder: (context, child) {
                  final elimination = _eliminationController.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.red.withOpacity(0.9 * (1 - elimination)),
                          Colors.orange.withOpacity(0.7 * (1 - elimination)),
                          Colors.yellow.withOpacity(0.5 * (1 - elimination)),
                          Colors.transparent,
                        ],
                        center: Alignment.center,
                        radius: elimination * 3.5,
                      ),
                    ),
                  );
                },
              ),

              // MAIN CONTENT
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ELIMINATION TITLE
                    AnimatedBuilder(
                      animation: _eliminationController,
                      builder: (context, child) {
                        final shake = math.sin(_eliminationController.value * math.pi * 8) * 5;

                        return Transform.translate(
                          offset: Offset(shake, 0),
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.red,
                                Colors.orange,
                                Colors.yellow,
                                Colors.red,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              '💥 ELIMINATED! 💥',
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
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // ELIMINATION STATS
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulsController.value * 0.1);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: RadialGradient(
                                colors: [
                                  Colors.red.withOpacity(0.9),
                                  Colors.orange.withOpacity(0.7),
                                  Colors.purple.withOpacity(0.5),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.6),
                                  blurRadius: 25,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  widget.isPractice
                                      ? 'Practice Round Failed'
                                      : 'Round ${widget.playerRound} Failed',
                                  style: GoogleFonts.chicle(
                                    fontSize: 24,
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
                                const SizedBox(height: 15),
                                Text(
                                  widget.isPractice
                                      ? 'Time to study the maze more carefully!\n\n'
                                      'Remember:\n'
                                      '• Focus during the study phase\n'
                                      '• Plan your route mentally\n'
                                      '• Move carefully to avoid wrong turns'
                                      : 'Your maze exploration ends here.\n\n'
                                      'Final Stats:\n'
                                      'Round ${widget.playerRound} Rank: #$_playerRank\n'
                                      'Rounds Survived: ${widget.playerRound}\n'
                                      'Time: ${(widget.completionTime / 1000).toStringAsFixed(2)}s',
                                  style: GoogleFonts.chicle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.95),
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
                                if (!widget.isPractice) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    '$_playersRemaining explorers still remain\n'
                                        'in the psychedelic maze...',
                                    style: GoogleFonts.chicle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // RETURN BUTTON
                    _buildReturnButton(
                        interpolatedColors,
                        widget.isPractice ? 'Try Again' : 'New Challenge'
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReturnButton(List<Color> colors, String text) {
    return AnimatedBuilder(
      animation: _pulsController,
      builder: (context, child) {
        final scale = 1.0 + (_pulsController.value * 0.1);
        final glow = 0.5 + (_pulsController.value * 0.5);

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () {
              if (widget.isPractice) {
                Navigator.pop(context);
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MazeLobbyScreen()),
                      (route) => false,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: RadialGradient(
                  colors: [
                    colors[2].withOpacity(0.9),
                    colors[4].withOpacity(0.7),
                    colors[1].withOpacity(0.5),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(glow),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: colors[3].withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Colors.white, Colors.yellow, Colors.white],
                ).createShader(bounds),
                child: Text(
                  text,
                  style: GoogleFonts.creepster(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 6,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}