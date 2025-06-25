// lib/screens/ultimate_tournament_game_screen.dart - GAME ORCHESTRATOR
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration, targetDuration;
import '../services/ultimate_tournament_service.dart';
import '../screens/precision_tap_screen.dart';
import '../screens/momentum_game_screen.dart';
import '../screens/memory_game_screen.dart';
import '../screens/match_game_screen.dart';
import '../screens/maze_game_screen.dart';
import 'ultimate_tournament_results_screen.dart';
import '../models/game_type.dart';


class UltimateTournamentGameScreen extends StatefulWidget {
  final String tourneyId;
  final List<GameType> gameOrder;

  const UltimateTournamentGameScreen({
    super.key,
    required this.tourneyId,
    required this.gameOrder,
  });

  @override
  State<UltimateTournamentGameScreen> createState() => _UltimateTournamentGameScreenState();
}

class _UltimateTournamentGameScreenState extends State<UltimateTournamentGameScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  int _currentGameIndex = 0;
  bool _isLoading = true;
  bool _gameCompleted = false;
  Timer? _transitionTimer;

  // Animations
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _transitionController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  @override
  void initState() {
    super.initState();

    // Initialize psychedelic background
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _initializeGame();
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    final ultimateColors = [
      Colors.red.shade800,
      Colors.orange.shade700,
      Colors.purple.shade800,
      Colors.pink.shade700,
      Colors.blue.shade800,
      Colors.green.shade700,
      Colors.cyan.shade600,
      Colors.yellow.shade600,
    ];

    return List.generate(
        6, (_) => ultimateColors[random.nextInt(ultimateColors.length)]);
  }

  Future<void> _initializeGame() async {
    try {
      // Get current game index from Firestore
      final tourneyDoc = await _db.collection('ultimate_tournaments').doc(widget.tourneyId).get();
      final data = tourneyDoc.data();

      if (data != null) {
        _currentGameIndex = data['currentGameIndex'] as int? ?? 0;
      }

      setState(() {
        _isLoading = false;
      });

      // Start the first game after a brief delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _startCurrentGame();
      }

    } catch (e) {
      print('🏆 Error initializing game: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startCurrentGame() {
    if (_currentGameIndex >= widget.gameOrder.length) {
      _showFinalResults();
      return;
    }

    final currentGame = widget.gameOrder[_currentGameIndex];
    print('🏆 Starting game ${_currentGameIndex + 1}/5: $currentGame');

    // Submit bot results for this game
    _submitBotResultsForGame(currentGame);

    // Navigate to the appropriate game screen
    switch (currentGame) {
      case GameType.precision:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _UltimatePrecisionWrapper(
              tourneyId: widget.tourneyId,
              onComplete: _onGameComplete,
            ),
          ),
        );
        break;

      case GameType.momentum:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _UltimateMomentumWrapper(
              tourneyId: widget.tourneyId,
              onComplete: _onGameComplete,
            ),
          ),
        );
        break;

      case GameType.memory:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _UltimateMemoryWrapper(
              tourneyId: widget.tourneyId,
              onComplete: _onGameComplete,
            ),
          ),
        );
        break;

      case GameType.match:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _UltimateMatchWrapper(
              tourneyId: widget.tourneyId,
              onComplete: _onGameComplete,
            ),
          ),
        );
        break;

      case GameType.maze:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _UltimateMazeWrapper(
              tourneyId: widget.tourneyId,
              onComplete: _onGameComplete,
            ),
          ),
        );
        break;
    }
  }

  Future<void> _submitBotResultsForGame(GameType gameType) async {
    try {
      // Get tournament bots
      final tourneyDoc = await _db.collection('ultimate_tournaments').doc(widget.tourneyId).get();
      final data = tourneyDoc.data();

      if (data != null && data.containsKey('bots')) {
        final botsData = data['bots'] as Map<String, dynamic>;
        final bots = <UltimateBotPlayer>[];

        for (final entry in botsData.entries) {
          final botData = entry.value as Map<String, dynamic>;
          final difficulty = UltimateBotDifficulty.values.firstWhere(
                (d) => d.name == botData['difficulty'],
            orElse: () => UltimateBotDifficulty.skilled,
          );

          bots.add(UltimateBotPlayer(
            id: entry.key,
            name: botData['name'],
            difficulty: difficulty,
          ));
        }

        // Submit bot results for this specific game
        await UltimateTournamentService.submitBotResults(
          widget.tourneyId,
          gameType.name,
          bots,
        );
      }
    } catch (e) {
      print('🏆 Error submitting bot results for ${gameType.name}: $e');
    }
  }

  void _onGameComplete(Map<String, dynamic> gameResult) {
    print('🏆 Game ${_currentGameIndex + 1} completed with result: $gameResult');

    // Save player result
    _savePlayerGameResult(gameResult);

    // Move to next game
    _currentGameIndex++;

    if (_currentGameIndex >= widget.gameOrder.length) {
      // All games completed
      _showFinalResults();
    } else {
      // Show transition screen and move to next game
      _showGameTransition();
    }
  }

  Future<void> _savePlayerGameResult(Map<String, dynamic> result) async {
    try {
      final currentGame = widget.gameOrder[_currentGameIndex];

      await _db
          .collection('ultimate_tournaments')
          .doc(widget.tourneyId)
          .collection('game_results')
          .doc('${_uid}_${currentGame.name}')
          .set({
        'playerId': _uid,
        'gameType': currentGame.name,
        'score': result['score'],
        'rank': result['rank'],
        'details': result['details'],
        'isBot': false,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Update tournament progress
      await UltimateTournamentService.advanceToNextGame(widget.tourneyId);

    } catch (e) {
      print('🏆 Error saving player game result: $e');
    }
  }

  void _showGameTransition() {
    setState(() {
      _gameCompleted = true;
    });

    _transitionController.forward();

    _transitionTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _gameCompleted = false;
        });
        _transitionController.reset();
        _startCurrentGame();
      }
    });
  }

  void _showFinalResults() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UltimateTournamentResultsScreen(
          tourneyId: widget.tourneyId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _backgroundController.dispose();
    _pulsController.dispose();
    _transitionController.dispose();
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
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.0,
                    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              if (_isLoading) _buildLoadingScreen(),
              if (_gameCompleted) _buildTransitionScreen(),
              if (!_isLoading && !_gameCompleted) _buildGameIntroScreen(),
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
              final scale = 1.0 + (_pulsController.value * 0.3);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.amber.withOpacity(0.9),
                        Colors.orange.withOpacity(0.7),
                        Colors.red.withOpacity(0.5),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.amber, Colors.orange, Colors.red],
            ).createShader(bounds),
            child: Text(
              'PREPARING ULTIMATE TOURNAMENT',
              style: GoogleFonts.creepster(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameIntroScreen() {
    if (_currentGameIndex >= widget.gameOrder.length) return Container();

    final currentGame = widget.gameOrder[_currentGameIndex];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'GAME ${_currentGameIndex + 1} OF 5',
            style: GoogleFonts.creepster(
              fontSize: 20,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _getGameColor(currentGame).withOpacity(0.9),
                  _getGameColor(currentGame).withOpacity(0.6),
                ],
              ),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(
              _getGameIcon(currentGame),
              size: 60,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 30),

          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                _getGameColor(currentGame),
                Colors.white,
                _getGameColor(currentGame),
              ],
            ).createShader(bounds),
            child: Text(
              _getGameName(currentGame).toUpperCase(),
              style: GoogleFonts.creepster(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            _getGameDescription(currentGame),
            style: GoogleFonts.chicle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionScreen() {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'GAME ${_currentGameIndex} COMPLETE!',
                style: GoogleFonts.creepster(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              if (_currentGameIndex < widget.gameOrder.length) ...[
                Text(
                  'NEXT GAME:',
                  style: GoogleFonts.chicle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  _getGameName(widget.gameOrder[_currentGameIndex]).toUpperCase(),
                  style: GoogleFonts.creepster(
                    fontSize: 32,
                    color: _getGameColor(widget.gameOrder[_currentGameIndex]),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                Text(
                  'ALL GAMES COMPLETE!',
                  style: GoogleFonts.creepster(
                    fontSize: 32,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Calculating final results...',
                  style: GoogleFonts.chicle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getGameColor(GameType game) {
    switch (game) {
      case GameType.precision:
        return Colors.red;
      case GameType.momentum:
        return Colors.orange;
      case GameType.memory:
        return Colors.purple;
      case GameType.match:
        return Colors.pink;
      case GameType.maze:
        return Colors.blue;
    }
  }

  IconData _getGameIcon(GameType game) {
    switch (game) {
      case GameType.precision:
        return Icons.timer;
      case GameType.momentum:
        return Icons.rotate_right;
      case GameType.memory:
        return Icons.psychology;
      case GameType.match:
        return Icons.style;
      case GameType.maze:
        return Icons.explore;
    }
  }

  String _getGameName(GameType game) {
    switch (game) {
      case GameType.precision:
        return 'Precision Tap';
      case GameType.momentum:
        return 'Momentum Madness';
      case GameType.memory:
        return 'Memory Madness';
      case GameType.match:
        return 'Match Madness';
      case GameType.maze:
        return 'Maze Madness';
    }
  }

  String _getGameDescription(GameType game) {
    switch (game) {
      case GameType.precision:
        return 'Stop the timer at exactly 3 seconds';
      case GameType.momentum:
        return 'Master the spinning wheel with building speed';
      case GameType.memory:
        return 'Remember and reproduce arrow patterns';
      case GameType.match:
        return 'Match pairs of psychedelic tarot cards';
      case GameType.maze:
        return 'Navigate mazes from memory';
    }
  }
}

// Wrapper classes for each game to handle Ultimate Tournament integration

class _UltimatePrecisionWrapper extends StatefulWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _UltimatePrecisionWrapper({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  State<_UltimatePrecisionWrapper> createState() => _UltimatePrecisionWrapperState();
}

class _UltimatePrecisionWrapperState extends State<_UltimatePrecisionWrapper> {
  @override
  Widget build(BuildContext context) {
    // Use modified precision tap screen that reports back to ultimate tournament
    return _ModifiedPrecisionTapScreen(
      target: targetDuration,
      tourneyId: widget.tourneyId,
      onComplete: widget.onComplete,
    );
  }
}

class _UltimateMomentumWrapper extends StatefulWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _UltimateMomentumWrapper({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  State<_UltimateMomentumWrapper> createState() => _UltimateMomentumWrapperState();
}

class _UltimateMomentumWrapperState extends State<_UltimateMomentumWrapper> {
  @override
  Widget build(BuildContext context) {
    return _ModifiedMomentumGameScreen(
      tourneyId: widget.tourneyId,
      onComplete: widget.onComplete,
    );
  }
}

class _UltimateMemoryWrapper extends StatefulWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _UltimateMemoryWrapper({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  State<_UltimateMemoryWrapper> createState() => _UltimateMemoryWrapperState();
}

class _UltimateMemoryWrapperState extends State<_UltimateMemoryWrapper> {
  @override
  Widget build(BuildContext context) {
    return _ModifiedMemoryGameScreen(
      tourneyId: widget.tourneyId,
      onComplete: widget.onComplete,
    );
  }
}

class _UltimateMatchWrapper extends StatefulWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _UltimateMatchWrapper({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  State<_UltimateMatchWrapper> createState() => _UltimateMatchWrapperState();
}

class _UltimateMatchWrapperState extends State<_UltimateMatchWrapper> {
  @override
  Widget build(BuildContext context) {
    return _ModifiedMatchGameScreen(
      tourneyId: widget.tourneyId,
      onComplete: widget.onComplete,
    );
  }
}

class _UltimateMazeWrapper extends StatefulWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _UltimateMazeWrapper({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  State<_UltimateMazeWrapper> createState() => _UltimateMazeWrapperState();
}

class _UltimateMazeWrapperState extends State<_UltimateMazeWrapper> {
  @override
  Widget build(BuildContext context) {
    return _ModifiedMazeGameScreen(
      tourneyId: widget.tourneyId,
      onComplete: widget.onComplete,
    );
  }
}

// Simplified modified game screens that call back to the ultimate tournament
// These would be minimal modifications to the existing game screens

class _ModifiedPrecisionTapScreen extends StatelessWidget {
  final Duration target;
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _ModifiedPrecisionTapScreen({
    required this.target,
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    // This would be a modified version of PrecisionTapScreen that calls
    // onComplete instead of navigating to results
    return PrecisionTapScreen(
      target: target,
      tourneyId: 'ultimate_$tourneyId',
      round: 1,
    );
  }
}

class _ModifiedMomentumGameScreen extends StatelessWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _ModifiedMomentumGameScreen({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return MomentumGameScreen(
      isPractice: false,
      tourneyId: 'ultimate_$tourneyId',
    );
  }
}

class _ModifiedMemoryGameScreen extends StatelessWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _ModifiedMemoryGameScreen({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return MemoryGameScreen(
      isPractice: false,
      tourneyId: 'ultimate_$tourneyId',
    );
  }
}

class _ModifiedMatchGameScreen extends StatelessWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _ModifiedMatchGameScreen({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return MatchGameScreen(
      isPractice: false,
      tourneyId: 'ultimate_$tourneyId',
    );
  }
}

class _ModifiedMazeGameScreen extends StatelessWidget {
  final String tourneyId;
  final Function(Map<String, dynamic>) onComplete;

  const _ModifiedMazeGameScreen({
    required this.tourneyId,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return MazeGameScreen(
      isPractice: false,
      survivalId: 'ultimate_$tourneyId',
      round: 1,
    );
  }
}