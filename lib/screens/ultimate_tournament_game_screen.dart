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
  bool _showingIntermediateResults = false;
  Timer? _transitionTimer;

  // Current standings after each game
  List<Map<String, dynamic>> _currentStandings = [];
  int _playerCurrentRank = 0;

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

  void _onGameComplete(Map<String, dynamic> gameResult) async {
    print('🏆 Game ${_currentGameIndex + 1} completed with result: $gameResult');

    // Save player result
    await _savePlayerGameResult(gameResult);

    // Get current standings after this game
    await _updateCurrentStandings();

    // Move to next game
    _currentGameIndex++;

    if (_currentGameIndex >= widget.gameOrder.length) {
      // All games completed
      _showFinalResults();
    } else {
      // Show intermediate results and move to next game
      _showIntermediateResults();
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

  Future<void> _updateCurrentStandings() async {
    try {
      print('🏆 Updating current standings after game ${_currentGameIndex + 1}');

      // Get current results for games completed so far
      final resultsSnapshot = await _db
          .collection('ultimate_tournaments')
          .doc(widget.tourneyId)
          .collection('game_results')
          .get();

      // Group results by player for games completed so far
      final Map<String, Map<String, dynamic>> playerResults = {};

      for (final doc in resultsSnapshot.docs) {
        final data = doc.data();
        final playerId = data['playerId'] as String;
        final gameType = data['gameType'] as String;
        final score = data['score'] as int;
        final rank = data['rank'] as int;

        // Only include games that have been completed
        final gameIndex = widget.gameOrder.indexWhere((g) => g.name == gameType);
        if (gameIndex > _currentGameIndex) continue; // Skip future games

        if (!playerResults.containsKey(playerId)) {
          playerResults[playerId] = {
            'playerId': playerId,
            'totalScore': 0,
            'gamesCompleted': 0,
            'averageRank': 0.0,
          };
        }

        playerResults[playerId]!['totalScore'] += score;
        playerResults[playerId]!['gamesCompleted'] += 1;
      }

      // Calculate average ranks and sort
      final standings = <Map<String, dynamic>>[];

      for (final playerData in playerResults.values) {
        // Only include players who have completed the current number of games
        if (playerData['gamesCompleted'] >= _currentGameIndex + 1) {
          standings.add(playerData);
        }
      }

      // Sort by total score (descending)
      standings.sort((a, b) => (b['totalScore'] as int).compareTo(a['totalScore'] as int));

      // Find player's current rank
      _playerCurrentRank = standings.indexWhere((player) => player['playerId'] == _uid) + 1;
      if (_playerCurrentRank == 0) _playerCurrentRank = 64; // If not found, assume last

      _currentStandings = standings;

      print('🏆 Current standings: Player rank $_playerCurrentRank out of ${standings.length}');
    } catch (e) {
      print('🏆 Error updating current standings: $e');
      _playerCurrentRank = 32; // Default fallback
    }
  }

  void _showIntermediateResults() {
    setState(() {
      _showingIntermediateResults = true;
    });

    _transitionController.forward();

    _transitionTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showingIntermediateResults = false;
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
              if (_showingIntermediateResults) _buildIntermediateResultsScreen(),
              if (!_isLoading && !_showingIntermediateResults) _buildGameIntroScreen(),
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

  Widget _buildIntermediateResultsScreen() {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Game Complete Header
                Text(
                  'GAME ${_currentGameIndex} COMPLETE!',
                  style: GoogleFonts.creepster(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Current Rank Display
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: RadialGradient(
                      colors: [
                        _getRankColor(_playerCurrentRank).withOpacity(0.8),
                        _getRankColor(_playerCurrentRank).withOpacity(0.5),
                        _getRankColor(_playerCurrentRank).withOpacity(0.3),
                      ],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'CURRENT STANDING',
                        style: GoogleFonts.creepster(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        '#$_playerCurrentRank',
                        style: GoogleFonts.chicle(
                          fontSize: 48,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),

                      Text(
                        'out of 64 ultimate warriors',
                        style: GoogleFonts.chicle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),

                      const SizedBox(height: 15),

                      Text(
                        'After ${_currentGameIndex} game${_currentGameIndex == 1 ? '' : 's'}',
                        style: GoogleFonts.chicle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                if (_currentGameIndex < widget.gameOrder.length) ...[
                  Text(
                    'NEXT GAME:',
                    style: GoogleFonts.chicle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _getGameColor(widget.gameOrder[_currentGameIndex]).withOpacity(0.9),
                          _getGameColor(widget.gameOrder[_currentGameIndex]).withOpacity(0.6),
                        ],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      _getGameIcon(widget.gameOrder[_currentGameIndex]),
                      size: 40,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    _getGameName(widget.gameOrder[_currentGameIndex]).toUpperCase(),
                    style: GoogleFonts.creepster(
                      fontSize: 24,
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

                const SizedBox(height: 30),

                // Progress indicator
                Text(
                  'Preparing next challenge...',
                  style: GoogleFonts.chicle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank <= 3) return Colors.orange;
    if (rank <= 10) return Colors.purple;
    if (rank <= 20) return Colors.blue;
    if (rank <= 32) return Colors.green;
    return Colors.red;
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
    return PrecisionTapScreen(
      target: targetDuration,
      tourneyId: 'ultimate_${widget.tourneyId}',
      round: 1,
      onUltimateComplete: widget.onComplete,
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
    return MomentumGameScreen(
      isPractice: false,
      tourneyId: 'ultimate_${widget.tourneyId}',
      onUltimateComplete: widget.onComplete,
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
    return MemoryGameScreen(
      isPractice: false,
      tourneyId: 'ultimate_${widget.tourneyId}',
      onUltimateComplete: widget.onComplete,
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
    return MatchGameScreen(
      isPractice: false,
      tourneyId: 'ultimate_${widget.tourneyId}',
      onUltimateComplete: widget.onComplete,
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
    return MazeGameScreen(
      isPractice: false,
      survivalId: 'ultimate_${widget.tourneyId}',
      round: 1,
      onUltimateComplete: widget.onComplete,
    );
  }
}